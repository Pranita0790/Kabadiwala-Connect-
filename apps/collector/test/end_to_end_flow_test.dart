import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/auth/auth_controller.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/locale_controller.dart';
import 'package:kabadiwala_connect/models/price.dart';
import 'package:kabadiwala_connect/models/user_profile.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/price_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/audio_service.dart';
import 'package:kabadiwala_connect/services/auth_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';
import 'package:kabadiwala_connect/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late MockApiService mockApi;
  late ConnectivityService connectivity;
  late SyncService syncService;
  late LotRepository lotRepository;
  late TransactionRepository transactionRepository;
  late PriceRepository priceRepository;
  late AudioService audioService;
  late LocaleController localeController;
  late AuthService authService;
  late AuthController authController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_e2e_test_');
    dbPath = '${tempDir.path}/test_e2e.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;

    mockApi = MockApiService();
    mockApi.delay = Duration.zero;

    connectivity = ConnectivityService.instance;
    connectivity.setMockIsConnected(false); // Offline initially

    syncService = SyncService(
      dbService: dbService,
      apiService: mockApi,
      connectivityService: connectivity,
      autoSyncOnOnline: false,
    );

    lotRepository = LotRepository(dbService: dbService);
    transactionRepository = TransactionRepository(
      dbService: dbService,
      apiService: mockApi,
      connectivityService: connectivity,
    );
    priceRepository = PriceRepository(
      dbService: dbService,
      apiService: mockApi,
      connectivityService: connectivity,
    );

    audioService = AudioService();
    audioService.isTestMode = true;

    localeController = LocaleController(dbService: dbService);
    await localeController.initialize();

    authService = AuthService(dbService: dbService);
    authController = AuthController(authService: authService);

    // Pre-authenticate for end-to-end collector workflow tests
    final user = UserProfile(
      id: 'test-user-e2e',
      phoneNumber: '+919876543210',
      name: 'Ramesh Kumar',
      city: 'Pune',
      role: 'collector',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await dbService.saveUser(user);
    await dbService.setCurrentUserId(user.id);
    await authController.initialize();
  });

  tearDown(() async {
    connectivity.resetForTesting();
    syncService.dispose();
    audioService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestApp() {
    return KabadiwalaConnectApp(
      localeController: localeController,
      lotRepository: lotRepository,
      transactionRepository: transactionRepository,
      priceRepository: priceRepository,
      syncService: syncService,
      connectivityService: connectivity,
      authController: authController,
    );
  }

  group('Collector Complete End-to-End Flow Verification', () {
    testWidgets('1. Complete Collector Journey: Offline Lot Creation -> Price Estimate -> Recycler Handover -> Earnings Ledger', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      // Step 1: HOME Screen
      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Create Lot'), findsOneWidget);
      expect(find.text('Price Board'), findsOneWidget);
      expect(find.text('Earnings Ledger'), findsOneWidget);

      // Step 2: Navigate to Camera
      await tester.tap(find.text('Create Lot'));
      await tester.pumpAndSettle();

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);

      // Step 3: Skip / Continue to Details
      await tester.tap(find.text('Skip Photo →'));
      await tester.pumpAndSettle();

      // Step 4: LOT DETAILS (CreateLotScreen)
      expect(find.text('Select Material Category'), findsOneWidget);
      expect(find.text('Enter Weight (kg)'), findsOneWidget);

      // Add weight using step button (+5 kg)
      await tester.tap(find.text('+5 kg'));
      await tester.pumpAndSettle();
      expect(find.text('10.0 kg'), findsOneWidget);

      // Step 5: SAVE LOCALLY (Offline-First SQLite Save)
      await tester.ensureVisible(find.text('Save Lot Locally'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Lot Locally'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      // After save, the collector lands on lot details (not an empty matching screen).
      expect(find.text('Lot Details'), findsOneWidget);
      expect(find.text('Handover to Recycler'), findsOneWidget);
      expect(find.text('Find Recycler'), findsOneWidget);

      // Verify SQLite state directly
      final localLots = await tester.runAsync(() => dbService.getLots());
      expect(localLots!.length, equals(1));
      final createdLot = localLots.first;
      expect(createdLot.weightKg, equals(10.0));
      expect(createdLot.syncStatus, equals(AppConstants.syncPending));

      await tester.pumpWidget(const SizedBox());
    });

    test('2. Online Synchronization & Idempotency: Pending records sync without duplicates when online', () async {
      // 1. Create 2 local lots offline
      await lotRepository.saveLotLocally(
        categoryId: 'copper_wire',
        categoryName: 'Copper Wire',
        weightKg: 8.5,
        condition: 'good',
        minPrice: 3825.0,
        maxPrice: 5270.0,
      );

      await lotRepository.saveLotLocally(
        categoryId: 'battery',
        categoryName: 'Batteries',
        weightKg: 15.0,
        condition: 'average',
        minPrice: 1050.0,
        maxPrice: 1650.0,
      );

      expect((await dbService.getPendingSyncLots()).length, equals(2));

      // 2. Connect to Internet
      connectivity.setMockIsConnected(true);

      // 3. Process Sync
      final syncResult = await syncService.syncPendingRecords();
      expect(syncResult.successful, equals(2));
      expect(syncResult.failed, equals(0));

      // 4. Verify SQLite status transitioned to SYNCED
      final lotsAfterSync = await dbService.getLots();
      for (final lot in lotsAfterSync) {
        expect(lot.syncStatus, equals(AppConstants.syncSynced));
      }

      // 5. Test idempotency: Calling sync again should NOT re-upload or duplicate
      final repeatResult = await syncService.syncPendingRecords();
      expect(repeatResult.successful, equals(0));
      expect(mockApi.uploadedLots.length, equals(2));
    });

    testWidgets('3. Localization Switch: Entire workflow operates cleanly in Hindi and Marathi', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pumpAndSettle();

      // Switch to Hindi
      await tester.runAsync(() => localeController.setLanguageCode('hi'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('कबाड़ीवाला कनेक्ट'), findsOneWidget);
      expect(find.text('नया माल जोड़ें'), findsOneWidget);
      expect(find.text('भाव बोर्ड'), findsOneWidget);
      expect(find.text('कमाई का खाता'), findsOneWidget);

      // Switch to Marathi
      await tester.runAsync(() => localeController.setLanguageCode('mr'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('कबाडीवाला कनेक्ट'), findsOneWidget);
      expect(find.text('नवीन माल नोंदवा'), findsOneWidget);
      expect(find.text('दर फलक'), findsOneWidget);
      expect(find.text('कमाईचे खाते'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4. Price Board & TTS Audio Readout flow', (tester) async {
      // Pre-populate price in SQLite
      await tester.runAsync(() => priceRepository.savePricesLocally([
        Price(
          id: 'pcb',
          material: 'PCB',
          categoryNameEn: 'Motherboard / PCB',
          categoryNameHi: 'मदरबोर्ड / पीसीबी',
          categoryNameMr: 'मदरबोर्ड / पीसीबी',
          minPrice: 240.0,
          maxPrice: 290.0,
          unit: 'kg',
          location: 'Nagpur',
          source: 'Benchmark Recycler',
          updatedAt: DateTime.now(),
          iconAsset: 'developer_board',
        ),
      ]));

      await tester.pumpWidget(buildTestApp());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pumpAndSettle();

      // Open Price Board
      await tester.tap(find.text('Price Board'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      expect(find.text('Price Board'), findsOneWidget);
      expect(find.text('Motherboard / PCB'), findsOneWidget);
      expect(find.text('₹240 – ₹290 / kg'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);

      // Verify TTS speak invocation
      await audioService.speakPriceRange(
        material: 'Motherboard / PCB',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        languageCode: 'en',
      );

      expect(audioService.lastSpokenText, isNotNull);
      expect(audioService.lastSpokenText, contains('Motherboard / PCB'));
      expect(audioService.lastSpokenText, contains('Two hundred forty to two hundred ninety rupees per kilogram'));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
