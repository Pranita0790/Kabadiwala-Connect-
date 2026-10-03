import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/app_notification.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/handover.dart';
import 'package:kabadiwala_connect/models/price.dart';
import 'package:kabadiwala_connect/models/recycler.dart';
import 'package:kabadiwala_connect/repositories/handover_repository.dart';
import 'package:kabadiwala_connect/repositories/recycler_repository.dart';
import 'package:kabadiwala_connect/screens/handover/handover_qr_screen.dart';
import 'package:kabadiwala_connect/screens/notifications/notifications_screen.dart';
import 'package:kabadiwala_connect/screens/recycler/recycler_matching_screen.dart';
import 'package:kabadiwala_connect/screens/safety/safety_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/audio_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/notification_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late MockApiService mockApiService;
  late ConnectivityService connectivityService;
  late RecyclerRepository recyclerRepository;
  late HandoverRepository handoverRepository;
  late SyncService syncService;
  late NotificationService notificationService;
  late AudioService audioService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_m3_test_');
    dbPath = '${tempDir.path}/test_m3.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;

    mockApiService = MockApiService();
    mockApiService.delay = Duration.zero;

    connectivityService = ConnectivityService.instance;
    connectivityService.setMockIsConnected(true);

    audioService = AudioService(isTestMode: true);
    AudioService.setInstance(audioService);

    recyclerRepository = RecyclerRepository(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
    );

    handoverRepository = HandoverRepository(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
    );

    syncService = SyncService(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
      autoSyncOnOnline: false,
    );
    SyncService.setInstance(syncService);

    notificationService = NotificationService(
      dbService: dbService,
      apiService: mockApiService,
    );
    NotificationService.setInstance(notificationService);
  });

  tearDown(() async {
    syncService.dispose();
    audioService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Member 3 — Task 1: Recycler Matching & Map Flow', () {
    test('1. Recycler matching returns compatible recyclers and ranks by distance & authorization', () async {
      // Seed test recyclers
      final List<Recycler> recyclers = [
        const Recycler(
          id: 'rec_01',
          name: 'Central E-Waste Recycler',
          address: 'Sitabuldi, Nagpur',
          acceptedCategories: ['pcb', 'copper'],
          distanceKm: 5.2,
          isAuthorized: false,
          latitude: 21.1458,
          longitude: 79.0882,
          indicativePrice: 240.0,
        ),
        const Recycler(
          id: 'rec_02',
          name: 'Authorized Maharashtra Green Tech',
          address: 'MIDC Hingna, Nagpur',
          acceptedCategories: ['pcb', 'battery', 'screen'],
          distanceKm: 3.8,
          isAuthorized: true,
          latitude: 21.1120,
          longitude: 79.0020,
          indicativePrice: 275.0,
        ),
        const Recycler(
          id: 'rec_03',
          name: 'Nagpur Battery Handlers',
          address: 'Ganeshpeth, Nagpur',
          acceptedCategories: ['battery'],
          distanceKm: 1.5,
          isAuthorized: true,
          latitude: 21.1400,
          longitude: 79.0900,
          indicativePrice: 120.0,
        ),
      ];

      await dbService.insertRecyclers(recyclers);

      // Exercise local ranking/filter (not the mock network catalog).
      connectivityService.setMockIsConnected(false);

      // Query matching recyclers for 'pcb'
      final pcbResult = await recyclerRepository.fetchMatchingRecyclers(categoryId: 'pcb');
      expect(pcbResult.recyclers.length, equals(2));
      // Authorized recycler should come first
      expect(pcbResult.recyclers.first.id, equals('rec_02'));
      expect(pcbResult.recyclers.first.isAuthorized, isTrue);
    });

    testWidgets('2. RecyclerMatchingScreen renders list, map toggle, and handles location fallback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<Recycler> testRecyclers = [
        const Recycler(
          id: 'rec_02',
          name: 'Authorized Maharashtra Green Tech',
          address: 'MIDC Hingna, Nagpur',
          acceptedCategories: ['pcb', 'battery'],
          distanceKm: 3.8,
          isAuthorized: true,
          latitude: 21.1120,
          longitude: 79.0020,
          indicativePrice: 275.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RecyclerMatchingScreen(
            selectedCategory: 'pcb',
            initialRecyclers: testRecyclers,
            recyclerRepository: recyclerRepository,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header and demo label
      expect(find.text('DEMO DATA'), findsOneWidget);
      expect(find.textContaining('Location permission unavailable'), findsOneWidget);
      expect(find.text('Authorized Maharashtra Green Tech'), findsOneWidget);

      // Toggle to Map View
      await tester.tap(find.byIcon(Icons.map_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('You'), findsOneWidget);
      expect(find.text('3.8km'), findsOneWidget);
    });
  });

  group('Member 3 — Task 2: QR Handover Generation & Safe Payload', () {
    test('1. Safe QR payload contains non-sensitive UUID identifiers only', () {
      final payloadStr = Handover.buildSafeQrPayload(
        handoverId: 'handover-1234-5678',
        lotId: 'lot-8765-4321',
        version: 1,
      );

      final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(decoded['handover_id'], equals('handover-1234-5678'));
      expect(decoded['lot_id'], equals('lot-8765-4321'));
      expect(decoded['version'], equals(1));
      expect(decoded['type'], equals('E_WASTE_HANDOVER'));

      // Ensure NO passwords, phone numbers, or payment credentials
      expect(decoded.containsKey('password'), isFalse);
      expect(decoded.containsKey('phone'), isFalse);
      expect(decoded.containsKey('payment'), isFalse);
    });

    test('2. Handover creation persists locally and updates transaction ledger on confirmation', () async {
      // Offline creation test
      connectivityService.setMockIsConnected(false);

      final lot = EWasteLot(
        id: 'lot_handover_test',
        categoryId: 'pcb',
        categoryName: 'Motherboard / PCB',
        weightKg: 8.0,
        condition: 'good',
        estimatedMinPrice: 2000.0,
        estimatedMaxPrice: 2400.0,
        status: 'READY_FOR_HANDOVER',
        syncStatus: AppConstants.syncPending,
        createdAt: DateTime.now(),
      );

      const recycler = Recycler(
        id: 'rec_handover_test',
        name: 'EcoRecycle Maharashtra',
        address: 'Nagpur',
        acceptedCategories: ['pcb'],
        distanceKm: 3.0,
        isAuthorized: true,
        latitude: 21.14,
        longitude: 79.08,
      );

      final handover = await handoverRepository.createHandoverLocally(
        lot: lot,
        recycler: recycler,
        agreedAmount: 2200.0,
      );

      expect(handover.id, isNotEmpty);
      expect(handover.status, equals(AppConstants.handoverPending));
      expect(handover.weightKg, equals(8.0));
      expect(handover.agreedAmount, equals(2200.0));

      // Verify stored locally in SQLite as PENDING_SYNC
      final stored = await dbService.getHandoverById(handover.id);
      expect(stored, isNotNull);
      expect(stored!.syncStatus, equals(AppConstants.syncPending));

      // Confirm handover
      final confirmed = await handoverRepository.confirmHandover(handover.id);
      expect(confirmed.status, equals(AppConstants.handoverConfirmed));
      expect(confirmed.confirmedAt, isNotNull);

      // Verify Transaction ledger created in SQLite
      final txs = await dbService.getTransactions();
      expect(txs.any((t) => t.lotId == lot.id), isTrue);

      // Verify in-app notification generated
      final notifs = await dbService.getNotifications();
      expect(notifs.any((n) => n.type == AppConstants.notificationHandover), isTrue);
    });

    testWidgets('3. HandoverQrScreen displays large QR and status states', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const recycler = Recycler(
        id: 'rec_qr_test',
        name: 'EcoRecycle Maharashtra',
        address: 'Nagpur',
        acceptedCategories: ['pcb'],
        distanceKm: 3.0,
        isAuthorized: true,
        latitude: 21.14,
        longitude: 79.08,
      );

      final testHandover = Handover(
        id: 'handover_qr_123',
        lotId: 'lot_qr_456',
        recyclerId: recycler.id,
        recyclerName: recycler.name,
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1300.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_qr_123',
          lotId: 'lot_qr_456',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HandoverQrScreen(
            recycler: recycler,
            initialHandover: testHandover,
            handoverRepository: handoverRepository,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ready for Handover'), findsOneWidget);
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.textContaining('Waiting for Recycler Confirmation'), findsOneWidget);
      expect(find.text('Simulate Recycler Confirmation (Demo)'), findsNothing);
      expect(find.text('Send lot to website'), findsOneWidget);
    });
  });

  group('Member 3 — Task 3: Safety Pictogram Screens', () {
    test('1. AppLocalizations contains complete translations for Member 3 in en, hi, mr', () {
      final m3Keys = [
        'recycler',
        'findRecycler',
        'recyclerDetails',
        'authorizedRecycler',
        'distance',
        'selectRecycler',
        'handover',
        'generateQr',
        'scanQr',
        'handoverConfirmed',
        'waitingForConfirmation',
        'safety',
        'safetyFirst',
        'wearGloves',
        'wearGlovesDesc',
        'doNotBurn',
        'doNotBurnDesc',
        'batteryWarning',
        'batteryWarningDesc',
        'avoidLeaking',
        'isolateDamaged',
        'authorizedOnly',
        'priceAlert',
        'priceTarget',
        'notification',
        'syncing',
        'syncFailed',
      ];

      for (final lang in ['en', 'hi', 'mr']) {
        final loc = AppLocalizations(Locale(lang));
        for (final key in m3Keys) {
          final val = loc.translate(key);
          expect(val, isNotEmpty, reason: 'Key "$key" should have translation in "$lang"');
          expect(val, isNot(equals(key)), reason: 'Key "$key" should not return raw key in "$lang"');
        }
      }
    });

    testWidgets('2. SafetyScreen displays safety topics with pictograms and audio in English', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testAudio = AudioService(isTestMode: true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SafetyScreen(audioService: testAudio),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Safety First'), findsWidgets);
      expect(find.text('Use Protective Gloves'), findsOneWidget);
      expect(find.text('Do Not Break Batteries'), findsOneWidget);
      expect(find.text('Never Burn E-Waste'), findsOneWidget);
    });

    testWidgets('3. SafetyScreen localization works in Hindi and Marathi', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testAudio = AudioService(isTestMode: true);

      // Test Hindi
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('hi'),
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('mr'),
          ],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SafetyScreen(audioService: testAudio),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('सुरक्षा सर्वोपरि'), findsWidgets);
      expect(find.text('सुरक्षात्मक दस्ताने पहनें'), findsOneWidget);
      expect(find.text('बैटरी को न तोड़ें'), findsOneWidget);
      expect(find.text('ई-कचरा कभी न जलाएं'), findsOneWidget);

      // Test Marathi
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('mr'),
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('mr'),
          ],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SafetyScreen(audioService: testAudio),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('सुरक्षा सर्वप्रथम'), findsWidgets);
      expect(find.text('संरक्षक हातमोजे वापरा'), findsOneWidget);
      expect(find.text('बॅटरी फोडू नका'), findsOneWidget);
      expect(find.text('ई-कचरा कधीही जाळू नका'), findsOneWidget);
    });
  });

  group('Member 3 — Task 4: Background Sync Service for Handovers', () {
    test('1. SyncService processes pending handovers when network is restored without duplication', () async {
      // 1. Create a handover offline
      connectivityService.setMockIsConnected(false);

      final handover = Handover(
        id: 'handover_sync_test_01',
        lotId: 'lot_sync_01',
        recyclerId: 'rec_01',
        recyclerName: 'Recycler Hub',
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1250.0,
        status: AppConstants.handoverConfirmed,
        qrPayload: '{"handover_id":"handover_sync_test_01"}',
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await dbService.insertHandover(handover);

      final pendingBefore = await dbService.getPendingSyncHandovers();
      expect(pendingBefore.length, equals(1));
      expect(pendingBefore.first.syncStatus, equals(AppConstants.syncPending));

      // 2. Restore network
      connectivityService.setMockIsConnected(true);

      // 3. Trigger sync
      final syncResult = await syncService.syncPendingRecords();
      expect(syncResult.successful, greaterThanOrEqualTo(1));

      // 4. Verify handover is now SYNCED in SQLite
      final syncedHandover = await dbService.getHandoverById('handover_sync_test_01');
      expect(syncedHandover!.syncStatus, equals(AppConstants.syncSynced));

      // 5. Subsequent sync should be idempotent
      final secondSync = await syncService.syncPendingRecords();
      expect(secondSync.successful, equals(0));
    });
  });

  group('Member 3 — Task 5: Notification System', () {
    test('1. Price alert triggers notification when market rate meets target', () async {
      // Create price alert for Copper at ₹700/kg
      await notificationService.createPriceAlert(
        categoryId: 'copper',
        categoryName: 'Copper Wire',
        targetPrice: 700.0,
      );

      // Current market prices: Copper hits ₹720/kg
      final prices = [
        Price(
          id: 'copper',
          material: 'Copper Wire',
          minPrice: 680.0,
          maxPrice: 720.0,
          unit: 'kg',
          location: 'Nagpur',
          source: 'Live Market',
          updatedAt: DateTime.now(),
        ),
      ];

      final count = await notificationService.checkPriceAlertsAgainstPrices(prices);
      expect(count, equals(1));

      // Verify notification in SQLite (1 created on setup + 1 on target reached)
      final notifs = await dbService.getNotifications();
      expect(notifs.length, equals(2));
      expect(notifs.every((n) => n.type == AppConstants.notificationPriceAlert), isTrue);
      expect(notifs.every((n) => !n.isRead), isTrue);

      // Mark as read
      for (final n in notifs) {
        await notificationService.markAsRead(n.id);
      }
      final unreadCount = await notificationService.getUnreadCount();
      expect(unreadCount, equals(0));
    });

    testWidgets('2. NotificationsScreen renders notifications and handles read states', (tester) async {
      // Seed notifications
      final notif = AppNotification(
        id: 'notif_ui_test',
        titleEn: '✓ Handover Confirmed',
        titleHi: '✓ माल हस्तांतरण निश्चित झाले',
        titleMr: '✓ माल हस्तांतरण निश्चित झाले',
        bodyEn: 'PCB lot handed over to EcoRecycle.',
        bodyHi: 'पीसीबी माल EcoRecycle को सौंपा गया।',
        bodyMr: 'पीसीबी माल EcoRecycle ला दिला.',
        type: AppConstants.notificationHandover,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NotificationsScreen(
            initialNotifications: [notif],
            notificationService: notificationService,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('✓ Handover Confirmed'), findsOneWidget);
      expect(find.text('PCB lot handed over to EcoRecycle.'), findsOneWidget);
    });
  });
}
