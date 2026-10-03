import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import '../models/e_waste_lot.dart';
import '../models/handover.dart';
import '../models/recycler.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

/// Repository managing material lot handovers, QR payloads, and transaction lifecycle.
/// Strictly enforces local-first writes before remote network requests.
class HandoverRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;
  final Uuid _uuid;

  HandoverRepository({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _apiService = apiService ?? RemoteApiService.instance,
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _uuid = const Uuid();

  /// Initiates a material handover locally in SQLite and generates a safe QR payload
  Future<Handover> createHandoverLocally({
    EWasteLot? lot,
    Recycler? recycler,
    String? lotId,
    String? recyclerId,
    String? recyclerName,
    String? materialCategory,
    double? weightKg,
    double? agreedPrice,
    double? agreedAmount,
  }) async {
    final handoverId = _uuid.v4();
    final effectiveLotId = lot?.id ?? lotId ?? _uuid.v4();
    final effectiveRecyclerId = recycler?.id ?? recyclerId ?? 'recycler-1';
    final effectiveRecyclerName = recycler?.name ?? recyclerName ?? 'Authorized Recycler';
    final effectiveMaterial = lot?.categoryName ?? materialCategory ?? 'pcb';
    final effectiveWeight = lot?.weightKg ?? weightKg ?? 1.0;
    final effectiveAmount = agreedPrice ?? agreedAmount ?? (lot != null ? (lot.estimatedMinPrice + lot.estimatedMaxPrice) / 2 : 500.0);

    final qrPayload = Handover.buildSafeQrPayload(
      handoverId: handoverId,
      lotId: effectiveLotId,
      version: 1,
    );

    final handover = Handover(
      id: handoverId,
      lotId: effectiveLotId,
      recyclerId: effectiveRecyclerId,
      recyclerName: effectiveRecyclerName,
      materialCategory: effectiveMaterial,
      weightKg: effectiveWeight,
      agreedAmount: effectiveAmount,
      status: AppConstants.handoverPending,
      qrPayload: qrPayload,
      createdAt: DateTime.now(),
      syncStatus: AppConstants.syncPending,
    );

    await _dbService.insertHandover(handover);

    // If online, attempt background sync
    final isOnline = await _connectivityService.isConnected();
    if (isOnline) {
      try {
        final res = await _apiService.uploadHandover(handover);
        if (res.success) {
          await _dbService.updateHandoverSyncStatus(handover.id, AppConstants.syncSynced);
        }
      } catch (_) {}
    }

    return handover;
  }

  /// Confirms a handover physically scanned/agreed by the recycler
  Future<Handover> confirmHandover(String handoverId, {double? finalAmount}) async {
    final existing = await _dbService.getHandoverById(handoverId);
    if (existing == null) {
      throw Exception('Handover $handoverId not found in local SQLite database');
    }

    final confirmedAt = DateTime.now();
    final effectiveFinalAmount = finalAmount ?? existing.agreedAmount;

    final updated = existing.copyWith(
      status: AppConstants.handoverConfirmed,
      confirmedAt: confirmedAt,
      agreedAmount: effectiveFinalAmount,
    );

    await _dbService.updateHandoverStatus(
      handoverId,
      AppConstants.handoverConfirmed,
      confirmedAt: confirmedAt,
    );

    // 1. Create a completed Transaction record in local SQLite ledger
    final tx = Transaction(
      id: _uuid.v4(),
      lotId: updated.lotId,
      recyclerId: updated.recyclerName,
      quotedPrice: updated.agreedAmount,
      finalPrice: effectiveFinalAmount,
      paymentStatus: 'PAID',
      handoverStatus: 'COMPLETED',
      createdAt: confirmedAt,
      categoryName: updated.materialCategory,
      weightKg: updated.weightKg,
    );
    await _dbService.insertTransaction(tx);

    // 2. Generate in-app notification
    final notif = AppNotification(
      id: _uuid.v4(),
      titleEn: '✓ Handover Confirmed',
      titleHi: '✓ माल हस्तांतरण निश्चित झाले',
      titleMr: '✓ माल हस्तांतरण निश्चित झाले',
      bodyEn: '${updated.materialCategory} (${updated.weightKg} kg) handed over to ${updated.recyclerName}. ₹${updated.agreedAmount.toStringAsFixed(0)} credited.',
      bodyHi: '${updated.materialCategory} (${updated.weightKg} किलो) ${updated.recyclerName} को सौंपा गया। ₹${updated.agreedAmount.toStringAsFixed(0)} प्राप्त।',
      bodyMr: '${updated.materialCategory} (${updated.weightKg} किलो) ${updated.recyclerName} ला दिले. ₹${updated.agreedAmount.toStringAsFixed(0)} जमा.',
      type: AppConstants.notificationHandover,
      relatedId: handoverId,
      timestamp: confirmedAt,
      isRead: false,
    );
    await _dbService.insertNotification(notif);

    // 3. Inform backend if online
    final isOnline = await _connectivityService.isConnected();
    if (isOnline) {
      try {
        await _apiService.confirmHandoverOnBackend(handoverId);
      } catch (_) {}
    }

    return updated;
  }

  Future<List<Handover>> getHandovers() => _dbService.getHandovers();

  Future<Handover?> getHandoverById(String id) => _dbService.getHandoverById(id);
}
