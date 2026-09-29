import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/handover.dart';
import 'package:kabadiwala_connect/models/recycler.dart';
import 'package:kabadiwala_connect/repositories/handover_repository.dart';
import 'package:kabadiwala_connect/screens/handover/handover_qr_screen.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late HandoverRepository handoverRepository;

  const sampleRecycler = Recycler(
    id: 'rec_qr_test',
    name: 'EcoRecycle Maharashtra',
    address: 'MIDC Hingna Industrial Area, Nagpur',
    acceptedCategories: ['pcb', 'battery'],
    distanceKm: 2.4,
    isAuthorized: true,
    rating: 4.8,
    latitude: 21.1458,
    longitude: 79.0882,
    indicativePrice: 320.0,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_handover_test_');
    dbPath = '${tempDir.path}/test_kabadiwala_handover.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    ConnectivityService.instance.setMockIsConnected(false);
    handoverRepository = HandoverRepository(dbService: DatabaseService.instance);
  });

  tearDown(() async {
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestWidget({
    Recycler recycler = sampleRecycler,
    EWasteLot? lot,
    Handover? initialHandover,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
        Locale('mr', ''),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HandoverQrScreen(
        recycler: recycler,
        lot: lot,
        initialHandover: initialHandover,
        handoverRepository: handoverRepository,
      ),
    );
  }

  group('HandoverQrScreen Responsive & Simulation Verification Tests', () {
    testWidgets('1. Content is fully visible, DEMO TEST TRIGGER is padded, and Simulate Recycler is visible', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHandover = Handover(
        id: 'handover_test_001',
        lotId: 'lot_test_001',
        recyclerId: sampleRecycler.id,
        recyclerName: sampleRecycler.name,
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1600.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_test_001',
          lotId: 'lot_test_001',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await tester.pumpWidget(buildTestWidget(initialHandover: testHandover));
      await tester.pumpAndSettle();

      // Verify Header & Status
      expect(find.text('Handover QR'), findsOneWidget);
      expect(find.text('Waiting for Recycler Confirmation'), findsOneWidget);
      expect(find.text('Ready for Handover'), findsOneWidget);

      // Verify Handover details
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.text('5.0 kg'), findsOneWidget);
      expect(find.text('₹1600'), findsOneWidget);

      // Verify DEMO TEST TRIGGER section & Simulate button
      expect(find.text('DEMO TEST TRIGGER'), findsOneWidget);
      expect(find.text('Simulate Recycler Confirmation (Demo)'), findsOneWidget);
    });

    testWidgets('2. Screen scrolls and fits naturally without overflow on small mobile viewport', (tester) async {
      // Set a smaller phone screen (e.g. 360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHandover = Handover(
        id: 'handover_test_002',
        lotId: 'lot_test_002',
        recyclerId: sampleRecycler.id,
        recyclerName: sampleRecycler.name,
        materialCategory: 'copper_wire',
        weightKg: 3.5,
        agreedAmount: 1120.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_test_002',
          lotId: 'lot_test_002',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await tester.pumpWidget(buildTestWidget(initialHandover: testHandover));
      await tester.pumpAndSettle();

      // Scroll to bottom to view simulation trigger
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('DEMO TEST TRIGGER'), findsOneWidget);
      expect(find.text('Simulate Recycler Confirmation (Demo)'), findsOneWidget);
    });

    testWidgets('3. Tapping Simulate Recycler confirms handover and switches to confirmed view', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create test lot & handover
      final testHandover = Handover(
        id: 'handover_test_003',
        lotId: 'lot_test_003',
        recyclerId: sampleRecycler.id,
        recyclerName: sampleRecycler.name,
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1600.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_test_003',
          lotId: 'lot_test_003',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await tester.runAsync(() async {
        await DatabaseService.instance.insertHandover(testHandover);
      });

      await tester.pumpWidget(buildTestWidget(initialHandover: testHandover));
      await tester.pumpAndSettle();

      // Tap Simulate Recycler button
      final simulateBtn = find.text('Simulate Recycler Confirmation (Demo)');
      await tester.ensureVisible(simulateBtn);

      await tester.runAsync(() async {
        await tester.tap(simulateBtn);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Status should update to Handover Confirmed and show View in Ledger button
      expect(find.text('Handover Confirmed'), findsWidgets);
      expect(find.text('View in Earnings Ledger'), findsWidgets);
    });

    testWidgets('4. Scanner action card and AppBar scanner icon are visible and trigger camera/scanner flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHandover = Handover(
        id: 'handover_test_004',
        lotId: 'lot_test_004',
        recyclerId: sampleRecycler.id,
        recyclerName: sampleRecycler.name,
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1600.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_test_004',
          lotId: 'lot_test_004',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      bool cameraRouteOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routes: {
            '/': (_) => HandoverQrScreen(
                  recycler: sampleRecycler,
                  initialHandover: testHandover,
                  handoverRepository: handoverRepository,
                ),
            '/camera': (_) {
              cameraRouteOpened = true;
              return const Scaffold(body: Text('MOCK_CAMERA_SCREEN'));
            },
          },
          initialRoute: '/',
        ),
      );
      await tester.pumpAndSettle();

      // Verify Scanner card exists
      expect(find.text('Scan QR'), findsWidgets);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);

      // Tap scanner action card
      await tester.tap(find.text('Scan QR').first);
      await tester.pumpAndSettle();

      expect(cameraRouteOpened, isTrue);
      expect(find.text('MOCK_CAMERA_SCREEN'), findsOneWidget);
    });

    testWidgets('5. Handover to Recycler button opens the detailed payment and weight confirmation form', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHandover = Handover(
        id: 'handover_test_005',
        lotId: 'lot_test_005',
        recyclerId: sampleRecycler.id,
        recyclerName: sampleRecycler.name,
        materialCategory: 'pcb',
        weightKg: 5.0,
        agreedAmount: 1600.0,
        status: AppConstants.handoverPending,
        qrPayload: Handover.buildSafeQrPayload(
          handoverId: 'handover_test_005',
          lotId: 'lot_test_005',
        ),
        createdAt: DateTime.now(),
        syncStatus: AppConstants.syncPending,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HandoverQrScreen(
            recycler: sampleRecycler,
            initialHandover: testHandover,
            handoverRepository: handoverRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find "Handover to Recycler" payment form button
      final paymentFormBtn = find.widgetWithText(OutlinedButton, 'Handover to Recycler');
      expect(paymentFormBtn, findsOneWidget);

      await tester.ensureVisible(paymentFormBtn);
      await tester.tap(paymentFormBtn);
      await tester.pumpAndSettle();

      // Detailed form screen should open
      expect(find.text('Select Authorized Recycler'), findsOneWidget);
      expect(find.text('Enter Weight (kg)'), findsOneWidget);
      expect(find.text('Payment Status'), findsOneWidget);

      final confirmBtn = find.text('Confirm Handover & Payment');
      expect(confirmBtn, findsOneWidget);
    });
  });
}
