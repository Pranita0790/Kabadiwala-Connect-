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
  late ConnectivityService connectivityService;
  late MockApiService mockApiService;
  late SyncService syncService;
  late LotRepository lotRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_sync_test_');
    dbPath = '${tempDir.path}/test_sync.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;

    connectivityService = ConnectivityService();
    connectivityService.resetForTesting();
    mockApiService = MockApiService();
    mockApiService.delay = Duration.zero; // instant for tests

    syncService = SyncService(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
      autoSyncOnOnline: false,
    );

    lotRepository = LotRepository(dbService: dbService);
  });

  tearDown(() async {
    syncService.dispose();
    connectivityService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Offline Synchronization Layer Tests', () {
    test('User Requested Scenario: 8-Step Offline-to-Online Sync Lifecycle', () async {
      // Step 1: Disable internet
      connectivityService.setMockIsConnected(false);
      expect(await connectivityService.isConnected(), isFalse);

      // Step 2: Create a material lot
      final createdLot = await lotRepository.saveLotLocally(
        categoryId: 'pcb_motherboard',
        categoryName: 'Motherboard / PCB',
        weightKg: 15.5,
        condition: 'good',
        notes: 'High-grade server boards',
        minPrice: 4500.0,
        maxPrice: 6500.0,
      );

      // Step 3: Confirm it is saved locally with PENDING_SYNC
      expect(createdLot.id, isNotEmpty);
      expect(createdLot.syncStatus, equals(AppConstants.syncPending));

      final locallySavedLot = await dbService.getLot(createdLot.id);
      expect(locallySavedLot, isNotNull);
      expect(locallySavedLot!.id, equals(createdLot.id));
      expect(locallySavedLot.weightKg, equals(15.5));
      expect(locallySavedLot.syncStatus, equals(AppConstants.syncPending));

      final pendingSyncItems = await dbService.getPendingSyncItems();
      expect(pendingSyncItems.any((item) => item.entityId == createdLot.id), isTrue);

      // Step 4: Close/reopen app (Simulate app restart by closing DB and re-opening)
      await DatabaseService.closeDatabase();
      DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
      final reloadedDb = DatabaseService.instance;

      // Step 5: Confirm lot still exists
      final reloadedLot = await reloadedDb.getLot(createdLot.id);
      expect(reloadedLot, isNotNull);
      expect(reloadedLot!.id, equals(createdLot.id));
      expect(reloadedLot.categoryName, equals('Motherboard / PCB'));
      expect(reloadedLot.weightKg, equals(15.5));
      expect(reloadedLot.syncStatus, equals(AppConstants.syncPending));

      // Step 6: Restore internet
      connectivityService.setMockIsConnected(true);
      expect(await connectivityService.isConnected(), isTrue);

      // Re-initialize sync service with the restored DB
      final activeSyncService = SyncService(
        dbService: reloadedDb,
        apiService: mockApiService,
        connectivityService: connectivityService,
        autoSyncOnOnline: false,
      );

      // Step 7: Trigger synchronization
      final syncResult = await activeSyncService.syncPendingRecords();

      // Step 8: Confirm status changes appropriately
      expect(syncResult.total, equals(1));
      expect(syncResult.successful, equals(1));
      expect(syncResult.failed, equals(0));

      final syncedLot = await reloadedDb.getLot(createdLot.id);
      expect(syncedLot, isNotNull);
      expect(syncedLot!.syncStatus, equals(AppConstants.syncSynced));

      // Verify sync queue item removed upon success
      final remainingQueue = await reloadedDb.getPendingSyncItems();
      expect(remainingQueue.any((item) => item.entityId == createdLot.id), isFalse);

      // Confirm ApiService received the lot exactly once
      expect(mockApiService.uploadedLots.length, equals(1));
      expect(mockApiService.uploadedLots.first.id, equals(createdLot.id));

      activeSyncService.dispose();
    });

    test('Sync Failure & Retry: Marks FAILED, increments retry_count, and avoids duplicates on retry', () async {
      connectivityService.setMockIsConnected(true);

      // Save a new lot
      final lot = await lotRepository.saveLotLocally(
        categoryId: 'copper_wire',
        categoryName: 'Copper Wire',
        weightKg: 10.0,
        condition: 'good',
        minPrice: 4500.0,
        maxPrice: 6200.0,
      );

      // Configure ApiService to simulate server failure
      mockApiService.shouldSucceed = false;

      // First sync attempt -> should fail
      final resultFail = await syncService.syncPendingRecords();
      expect(resultFail.total, equals(1));
      expect(resultFail.failed, equals(1));
      expect(resultFail.successful, equals(0));

      // Verify lot is marked FAILED
      final failedLot = await dbService.getLot(lot.id);
      expect(failedLot!.syncStatus, equals(AppConstants.syncFailed));

      // Verify retry_count was incremented to 1
      final queueItems = await dbService.getPendingSyncItems();
      final item = queueItems.firstWhere((q) => q.entityId == lot.id);
      expect(item.retryCount, equals(1));

      // Now server recovers
      mockApiService.shouldSucceed = true;

      // Second sync attempt (Retry) -> should succeed
      final resultRetry = await syncService.syncPendingRecords();
      expect(resultRetry.successful, equals(1));
      expect(resultRetry.failed, equals(0));

      // Verify status is now SYNCED
      final syncedLot = await dbService.getLot(lot.id);
      expect(syncedLot!.syncStatus, equals(AppConstants.syncSynced));

      // Verify zero duplicates in mock backend
      final matchingUploaded = mockApiService.uploadedLots.where((l) => l.id == lot.id).toList();
      expect(matchingUploaded.length, equals(1));
    });

    test('Offline Sync Prevention: SyncService aborts cleanly when offline', () async {
      connectivityService.setMockIsConnected(false);

      await lotRepository.saveLotLocally(
        categoryId: 'battery',
        categoryName: 'Lithium Battery',
        weightKg: 5.0,
        condition: 'average',
        minPrice: 800.0,
        maxPrice: 1200.0,
      );

      final result = await syncService.syncPendingRecords();
      expect(result.isOffline, isTrue);
      expect(result.successful, equals(0));
      expect(syncService.currentStatus, equals(SyncStatus.waitingForInternet));
    });
  });
}
