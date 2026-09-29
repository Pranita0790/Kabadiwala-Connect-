import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late LotRepository lotRepo;
  late MockApiService mockApiService;
  late ConnectivityService connectivityService;
  late SyncService syncService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_sync_test_');
    dbPath = '${tempDir.path}/test_offline_sync.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);

    dbService = DatabaseService.instance;
    lotRepo = LotRepository(dbService: dbService);
    mockApiService = MockApiService()..delay = Duration.zero;
    connectivityService = ConnectivityService.instance;
    syncService = SyncService(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
      autoSyncOnOnline: false,
    );
  });

  tearDown(() async {
    syncService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Offline Synchronization Layer - 8-Step Lifecycle Test', () {
    test('Complete 8-step lifecycle: offline save -> persistence -> online sync -> state transition', () async {
      // -------------------------------------------------------------
      // Step 1: Disable internet (simulate offline field conditions)
      // -------------------------------------------------------------
      connectivityService.setMockIsConnected(false);
      final isOffline = await connectivityService.isConnected();
      expect(isOffline, isFalse, reason: 'Internet should be disabled');

      // -------------------------------------------------------------
      // Step 2: Create a material lot
      // -------------------------------------------------------------
      final createdLot = await lotRepo.saveLotLocally(
        categoryId: 'pcb_motherboard',
        categoryName: 'Motherboard / मदरबोर्ड',
        weightKg: 5.5,
        condition: 'good',
        notes: 'Collected from electronic shop',
        minPrice: 1100.0,
        maxPrice: 1375.0,
      );

      // -------------------------------------------------------------
      // Step 3: Confirm lot is saved locally with PENDING_SYNC status
      // -------------------------------------------------------------
      expect(createdLot.id, isNotEmpty);
      expect(createdLot.syncStatus, equals(AppConstants.syncPending));

      // Verify in database
      final initialLots = await dbService.getLots();
      expect(initialLots.length, equals(1));
      expect(initialLots.first.id, equals(createdLot.id));
      expect(initialLots.first.syncStatus, equals(AppConstants.syncPending));
      expect(initialLots.first.weightKg, equals(5.5));

      // Verify sync queue item was created atomically with retry_count = 0
      final queueItems = await dbService.getPendingSyncItems();
      expect(queueItems.length, equals(1));
      expect(queueItems.first.entityId, equals(createdLot.id));
      expect(queueItems.first.retryCount, equals(0));

      // Attempting sync while offline should be blocked
      final offlineResult = await syncService.syncPendingRecords();
      expect(offlineResult.isOffline, isTrue);
      expect(offlineResult.successful, equals(0));
      expect(syncService.currentStatus, equals(SyncStatus.waitingForInternet));

      // -------------------------------------------------------------
      // Step 4: Close/reopen app (Simulate App Restart & DB Reconnect)
      // -------------------------------------------------------------
      await DatabaseService.closeDatabase();

      // Re-initialize database instance pointing to the same file
      DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
      final reconnectedDb = DatabaseService.instance;
      final reconnectedRepo = LotRepository(dbService: reconnectedDb);

      // -------------------------------------------------------------
      // Step 5: Confirm lot still exists with exact metadata & PENDING_SYNC
      // -------------------------------------------------------------
      final persistedLots = await reconnectedRepo.getLots();
      expect(persistedLots.length, equals(1));
      expect(persistedLots.first.id, equals(createdLot.id));
      expect(persistedLots.first.categoryName, equals('Motherboard / मदरबोर्ड'));
      expect(persistedLots.first.weightKg, equals(5.5));
      expect(persistedLots.first.syncStatus, equals(AppConstants.syncPending));

      final persistedQueue = await reconnectedDb.getPendingSyncItems();
      expect(persistedQueue.length, equals(1));
      expect(persistedQueue.first.entityId, equals(createdLot.id));

      // -------------------------------------------------------------
      // Step 6: Restore internet
      // -------------------------------------------------------------
      connectivityService.setMockIsConnected(true);
      final isOnline = await connectivityService.isConnected();
      expect(isOnline, isTrue, reason: 'Internet should be restored');

      // -------------------------------------------------------------
      // Step 7: Trigger synchronization
      // -------------------------------------------------------------
      final reconnectedSync = SyncService(
        dbService: reconnectedDb,
        apiService: mockApiService,
        connectivityService: connectivityService,
        autoSyncOnOnline: false,
      );

      final syncResult = await reconnectedSync.syncPendingRecords();

      // -------------------------------------------------------------
      // Step 8: Confirm status changes appropriately
      // -------------------------------------------------------------
      expect(syncResult.successful, equals(1));
      expect(syncResult.failed, equals(0));
      expect(syncResult.isOffline, isFalse);
      expect(reconnectedSync.currentStatus, equals(SyncStatus.synced));

      // Verify backend received the lot
      expect(mockApiService.uploadCallCount, equals(1));
      expect(mockApiService.uploadedLots.length, equals(1));
      expect(mockApiService.uploadedLots.first.id, equals(createdLot.id));

      // Verify database lot status transitioned to SYNCED
      final syncedLots = await reconnectedRepo.getLots();
      expect(syncedLots.first.syncStatus, equals(AppConstants.syncSynced));

      // Verify sync_queue was purged upon successful sync
      final remainingQueue = await reconnectedDb.getPendingSyncItems();
      expect(remainingQueue, isEmpty);

      reconnectedSync.dispose();
    });

    test('Failure handling: increments retry_count, marks FAILED, and avoids duplicates on retry', () async {
      connectivityService.setMockIsConnected(true);

      // Create a test lot
      final lot = await lotRepo.saveLotLocally(
        categoryId: 'crt_monitor',
        categoryName: 'CRT Monitor',
        weightKg: 12.0,
        condition: 'scrap',
        minPrice: 300.0,
        maxPrice: 450.0,
      );

      // 1. Simulate API failure
      mockApiService.shouldSucceed = false;

      final failResult = await syncService.syncPendingRecords();
      expect(failResult.failed, equals(1));
      expect(failResult.successful, equals(0));
      expect(syncService.currentStatus, equals(SyncStatus.failed));

      // Verify status is FAILED and retry_count is incremented to 1
      final failedLots = await dbService.getLots();
      expect(failedLots.first.id, equals(lot.id));
      expect(failedLots.first.syncStatus, equals(AppConstants.syncFailed));

      final queueAfterFail = await dbService.getPendingSyncItems();
      expect(queueAfterFail.length, equals(1));
      expect(queueAfterFail.first.retryCount, equals(1));

      // 2. Simulate API recovery on retry
      mockApiService.shouldSucceed = true;

      final retryResult = await syncService.syncPendingRecords();
      expect(retryResult.successful, equals(1));
      expect(retryResult.failed, equals(0));
      expect(syncService.currentStatus, equals(SyncStatus.synced));

      // Verify record is now SYNCED
      final syncedLots = await dbService.getLots();
      expect(syncedLots.length, equals(1), reason: 'Zero duplicates created on retry');
      expect(syncedLots.first.syncStatus, equals(AppConstants.syncSynced));

      // Verify queue is cleaned up
      final queueAfterSuccess = await dbService.getPendingSyncItems();
      expect(queueAfterSuccess, isEmpty);
    });

    test('Automatic synchronization on connectivity restoration stream', () async {
      connectivityService.setMockIsConnected(false);

      final autoSyncService = SyncService(
        dbService: dbService,
        apiService: mockApiService,
        connectivityService: connectivityService,
        autoSyncOnOnline: true,
      );

      await lotRepo.saveLotLocally(
        categoryId: 'mobile_phones',
        categoryName: 'Smartphones / स्मार्टफोन',
        weightKg: 2.0,
        condition: 'broken',
        minPrice: 500.0,
        maxPrice: 800.0,
      );

      // Verify pending lot
      final beforeLots = await dbService.getLots();
      expect(beforeLots.first.syncStatus, equals(AppConstants.syncPending));

      // Restore internet -> triggers stream listener
      connectivityService.setMockIsConnected(true);

      // Wait a microtask cycle for stream event
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify automatically marked as SYNCED
      final afterLots = await dbService.getLots();
      expect(afterLots.first.syncStatus, equals(AppConstants.syncSynced));

      autoSyncService.dispose();
    });
  });
}
