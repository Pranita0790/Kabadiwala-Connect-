import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/price.dart';
import 'package:kabadiwala_connect/models/transaction.dart' as app_model;
import 'package:kabadiwala_connect/models/sync_queue_item.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite FFI for local unit testing on Windows/CI
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_db_test_');
    dbPath = '${tempDir.path}/test_kabadiwala.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;
  });

  tearDown(() async {
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DatabaseService Tests - Central SQLite Data Layer', () {
    test('1. Inserting a lot creates database record and atomic sync queue entry', () async {
      final now = DateTime.now();
      final lot = EWasteLot(
        id: 'test_lot_101',
        categoryId: 'pcb_motherboard',
        categoryName: 'Motherboard / PCB',
        weightKg: 12.5,
        condition: 'good',
        imagePath: '/images/test_pcb.jpg',
        notes: 'Test PCB bundle',
        estimatedMinPrice: 3500.0,
        estimatedMaxPrice: 5250.0,
        status: 'CREATED',
        syncStatus: AppConstants.syncPending,
        createdAt: now,
      );

      await dbService.insertLot(lot);

      final fetchedLot = await dbService.getLot('test_lot_101');
      expect(fetchedLot, isNotNull);
      expect(fetchedLot!.id, equals('test_lot_101'));
      expect(fetchedLot.categoryName, equals('Motherboard / PCB'));
      expect(fetchedLot.weightKg, equals(12.5));
      expect(fetchedLot.condition, equals('good'));
      expect(fetchedLot.syncStatus, equals(AppConstants.syncPending));

      // Verify atomic sync_queue entry was created
      final pendingSyncItems = await dbService.getPendingSyncItems();
      expect(pendingSyncItems.any((item) => item.entityId == 'test_lot_101'), isTrue);
    });

    test('2. Reading a lot and reading all lots', () async {
      final lot1 = EWasteLot(
        id: 'lot_read_1',
        categoryId: 'copper_wire',
        categoryName: 'Copper Wire',
        weightKg: 8.0,
        condition: 'good',
        estimatedMinPrice: 3600.0,
        estimatedMaxPrice: 4960.0,
        status: 'CREATED',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      final lot2 = EWasteLot(
        id: 'lot_read_2',
        categoryId: 'battery',
        categoryName: 'Batteries',
        weightKg: 20.0,
        condition: 'average',
        estimatedMinPrice: 1400.0,
        estimatedMaxPrice: 2200.0,
        status: 'CREATED',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      await dbService.insertLot(lot1);
      await dbService.insertLot(lot2);

      final singleLot = await dbService.getLot('lot_read_1');
      expect(singleLot, isNotNull);
      expect(singleLot!.categoryName, equals('Copper Wire'));

      final allLots = await dbService.getLots();
      expect(allLots.length, greaterThanOrEqualTo(2));
      expect(allLots.map((l) => l.id), containsAll(['lot_read_1', 'lot_read_2']));
    });

    test('3. Updating a lot modifies properties and adds sync record', () async {
      final initialLot = EWasteLot(
        id: 'lot_update_1',
        categoryId: 'display_monitor',
        categoryName: 'Monitors & Displays',
        weightKg: 5.0,
        condition: 'average',
        estimatedMinPrice: 500.0,
        estimatedMaxPrice: 1000.0,
        status: 'CREATED',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      await dbService.insertLot(initialLot);

      final updatedLot = initialLot.copyWith(
        weightKg: 15.0,
        condition: 'good',
        status: 'PROCESSED',
        notes: 'Updated monitor weight after re-weighing',
      );

      await dbService.updateLot(updatedLot);

      final fetched = await dbService.getLot('lot_update_1');
      expect(fetched, isNotNull);
      expect(fetched!.weightKg, equals(15.0));
      expect(fetched.condition, equals('good'));
      expect(fetched.status, equals('PROCESSED'));
      expect(fetched.notes, equals('Updated monitor weight after re-weighing'));
    });

    test('4. Data persistence after reopening the database', () async {
      final lotToPersist = EWasteLot(
        id: 'persistent_lot_999',
        categoryId: 'mixed_ewaste',
        categoryName: 'Mixed E-Waste',
        weightKg: 45.0,
        condition: 'scrap',
        estimatedMinPrice: 9000.0,
        estimatedMaxPrice: 13500.0,
        status: 'STORED',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      final priceToPersist = Price(
        id: 'copper_wire_price',
        material: 'Copper Wire',
        minPrice: 450.0,
        maxPrice: 620.0,
        unit: 'kg',
        location: 'Mumbai Central',
        source: 'Formal Recycler Rate',
      );

      await dbService.insertLot(lotToPersist);
      await dbService.insertPrice(priceToPersist);

      // Simulate closing the app / database connection
      await DatabaseService.closeDatabase();

      // Reopen database from the exact same file path
      DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
      final newDbService = DatabaseService.instance;

      final restoredLot = await newDbService.getLot('persistent_lot_999');
      expect(restoredLot, isNotNull);
      expect(restoredLot!.weightKg, equals(45.0));
      expect(restoredLot.categoryName, equals('Mixed E-Waste'));

      final restoredPrices = await newDbService.getPrices();
      expect(restoredPrices.any((p) => p.id == 'copper_wire_price'), isTrue);
    });

    test('5. Pending sync records and state transitions (markAsSynced & markAsSyncFailed)', () async {
      final lotSyncTest = EWasteLot(
        id: 'sync_test_777',
        categoryId: 'pcb_motherboard',
        categoryName: 'Motherboard',
        weightKg: 10.0,
        condition: 'good',
        estimatedMinPrice: 2800.0,
        estimatedMaxPrice: 4200.0,
        status: 'CREATED',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      await dbService.insertLot(lotSyncTest);

      var pendingLots = await dbService.getPendingSyncLots();
      expect(pendingLots.any((l) => l.id == 'sync_test_777'), isTrue);

      // Test markAsSyncFailed
      await dbService.markAsSyncFailed('sync_test_777', error: 'Network timeout');
      final failedLot = await dbService.getLot('sync_test_777');
      expect(failedLot!.syncStatus, equals(AppConstants.syncFailed));

      // FAILED lots are still included in pending sync
      pendingLots = await dbService.getPendingSyncLots();
      expect(pendingLots.any((l) => l.id == 'sync_test_777'), isTrue);

      // Test markAsSynced
      await dbService.markAsSynced('sync_test_777');
      final syncedLot = await dbService.getLot('sync_test_777');
      expect(syncedLot!.syncStatus, equals(AppConstants.syncSynced));

      // After synced, should not appear in pending
      pendingLots = await dbService.getPendingSyncLots();
      expect(pendingLots.any((l) => l.id == 'sync_test_777'), isFalse);
    });

    test('6. Transactions table operations with payment & handover status', () async {
      final tx = app_model.Transaction(
        id: 'tx_001',
        lotId: 'test_lot_101',
        recyclerId: 'recycler_mumbai_01',
        quotedPrice: 4000.0,
        finalPrice: 4200.0,
        paymentStatus: 'RECEIVED',
        handoverStatus: 'COMPLETED',
        categoryName: 'Motherboard / PCB',
        weightKg: 12.5,
      );

      await dbService.insertTransaction(tx);

      final txList = await dbService.getTransactions();
      expect(txList.length, equals(1));
      expect(txList.first.id, equals('tx_001'));
      expect(txList.first.finalPrice, equals(4200.0));
      expect(txList.first.paymentStatus, equals('RECEIVED'));
      expect(txList.first.handoverStatus, equals('COMPLETED'));
    });

    test('7. addToSyncQueue and getPendingSyncItems work correctly', () async {
      final item = SyncQueueItem(
        id: 'sq_manual_001',
        entityType: 'PRICE',
        entityId: 'copper_wire',
        operation: 'UPDATE',
        createdAt: DateTime.now(),
      );

      await dbService.addToSyncQueue(item);

      final items = await dbService.getPendingSyncItems();
      expect(items.any((i) => i.id == 'sq_manual_001'), isTrue);
      final found = items.firstWhere((i) => i.id == 'sq_manual_001');
      expect(found.entityType, equals('PRICE'));
      expect(found.operation, equals('UPDATE'));
      expect(found.retryCount, equals(0));
    });
  });
}
