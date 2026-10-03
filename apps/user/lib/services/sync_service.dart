import 'dart:async';
import '../core/constants/app_constants.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';

enum SyncStatus {
  idle,
  waitingForInternet,
  syncing,
  synced,
  failed,
}

/// Synchronization Service implementing the state machine:
/// LOCAL DATA FIRST -> NETWORK SYNC SECOND
///
/// Sync States:
/// PENDING_SYNC -> SYNCING -> SYNCED | FAILED
class SyncService {
  static SyncService? _instance;

  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;

  StreamSubscription<bool>? _connectivitySubscription;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isSyncInProgress = false;

  final bool autoSyncOnOnline;

  SyncService({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
    this.autoSyncOnOnline = true,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _apiService = apiService ?? RemoteApiService(),
        _connectivityService = connectivityService ?? ConnectivityService.instance {
    _instance = this;
    if (autoSyncOnOnline) {
      _initConnectivityListener();
    }
  }

  static void setInstance(SyncService? instance) {
    _instance = instance;
  }

  factory SyncService.getInstance({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
  }) {
    _instance ??= SyncService(
      dbService: dbService,
      apiService: apiService,
      connectivityService: connectivityService,
    );
    return _instance!;
  }

  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;
  
  /// Stream mapping SyncStatus to AppConstants string representation
  Stream<String> get syncStateStream => _statusController.stream.map((status) {
    switch (status) {
      case SyncStatus.syncing:
        return AppConstants.syncSyncing;
      case SyncStatus.synced:
        return AppConstants.syncSynced;
      case SyncStatus.failed:
        return AppConstants.syncFailed;
      case SyncStatus.waitingForInternet:
      case SyncStatus.idle:
        return AppConstants.syncPending;
    }
  });

  bool get isSyncInProgress => _isSyncInProgress;

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) async {
      if (isOnline) {
        // When connectivity is detected, automatically sync pending records in background
        await syncPendingRecords();
      } else {
        _setStatus(SyncStatus.waitingForInternet);
      }
    });
  }

  /// Processes all pending and failed local records (Lots and Handovers) through the sync pipeline.
  ///
  /// Steps:
  /// 1. Check network connectivity.
  /// 2. Find pending local records (PENDING_SYNC and FAILED).
  /// 3. Transition sync state to SYNCING.
  /// 4. Dispatch to ApiService (proposed POST /api/lots, POST /api/handovers).
  /// 5. On success: mark record SYNCED.
  /// 6. On failure: mark record FAILED and increment retry_count.
  /// 7. Guarantee idempotency / zero duplicate creation.
  Future<SyncResult> syncPendingRecords() async {
    if (_isSyncInProgress) {
      return SyncResult(total: 0, successful: 0, failed: 0, isOffline: false);
    }

    final isConnected = await _connectivityService.isConnected();
    if (!isConnected) {
      _setStatus(SyncStatus.waitingForInternet);
      return SyncResult(total: 0, successful: 0, failed: 0, isOffline: true);
    }

    _isSyncInProgress = true;
    _setStatus(SyncStatus.syncing);

    int successCount = 0;
    int failCount = 0;

    try {
      final pendingLots = await _dbService.getPendingSyncLots();
      final pendingHandovers = await _dbService.getPendingSyncHandovers();
      final totalRecords = pendingLots.length + pendingHandovers.length;

      if (totalRecords == 0) {
        _setStatus(SyncStatus.synced);
        _isSyncInProgress = false;
        return SyncResult(total: 0, successful: 0, failed: 0, isOffline: false);
      }

      // 1. Sync pending lots
      for (final lot in pendingLots) {
        await _dbService.updateSyncStatus(lot.id, AppConstants.syncSyncing);

        try {
          final response = await _apiService.uploadLot(lot);

          if (response.success) {
            await _dbService.markAsSynced(lot.id);
            successCount++;
          } else {
            await _dbService.markAsSyncFailed(lot.id, error: response.errorMessage);
            failCount++;
          }
        } catch (e) {
          await _dbService.markAsSyncFailed(lot.id, error: e.toString());
          failCount++;
        }
      }

      // 2. Sync pending handovers (Member 3)
      for (final handover in pendingHandovers) {
        await _dbService.updateHandoverSyncStatus(
          handover.id,
          AppConstants.syncSyncing,
        );

        try {
          final response = await _apiService.uploadHandover(handover);

          if (response.success) {
            await _dbService.updateHandoverSyncStatus(
              handover.id,
              AppConstants.syncSynced,
            );
            successCount++;
          } else {
            await _dbService.updateHandoverSyncStatus(
              handover.id,
              AppConstants.syncFailed,
              retryCount: handover.retryCount + 1,
            );
            failCount++;
          }
        } catch (e) {
          await _dbService.updateHandoverSyncStatus(
            handover.id,
            AppConstants.syncFailed,
            retryCount: handover.retryCount + 1,
          );
          failCount++;
        }
      }

      if (failCount > 0) {
        _setStatus(SyncStatus.failed);
      } else {
        _setStatus(SyncStatus.synced);
      }

      return SyncResult(
        total: totalRecords,
        successful: successCount,
        failed: failCount,
        isOffline: false,
      );
    } catch (e) {
      _setStatus(SyncStatus.failed);
      return SyncResult(
        total: 0,
        successful: successCount,
        failed: failCount,
        isOffline: false,
      );
    } finally {
      _isSyncInProgress = false;
    }
  }

  // Alias for backward compatibility
  Future<int> syncPendingLots() async {
    final result = await syncPendingRecords();
    return result.successful;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

class SyncResult {
  final int total;
  final int successful;
  final int failed;
  final bool isOffline;

  SyncResult({
    required this.total,
    required this.successful,
    required this.failed,
    required this.isOffline,
  });
}
