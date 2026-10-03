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
    testWidgets('1. Content is fully visible, PIN is shown, and demo trigger is absent', (tester) async {
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
      expect(find.text('Handover PIN'), findsWidgets);
      expect(find.text('Waiting for Recycler Confirmation'), findsOneWidget);
      expect(find.text('Ready for Handover'), findsOneWidget);

      // PIN digits derived from lot id
      final expectedPin = Handover.deriveHandoverPin('lot_test_001');
      expect(find.text(expectedPin), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);

      // Verify Handover details
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.text('5.0 kg'), findsOneWidget);
      expect(find.text('₹1600'), findsOneWidget);

      expect(find.text('DEMO TEST TRIGGER'), findsNothing);
      expect(find.text('Simulate Recycler Confirmation (Demo)'), findsNothing);
      expect(find.text('Send lot to website'), findsOneWidget);
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

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('DEMO TEST TRIGGER'), findsNothing);
      expect(find.text('Send lot to website'), findsOneWidget);
    });

    testWidgets('3. Pending PIN screen waits for website and does not confirm locally', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      expect(find.text('Waiting for Recycler Confirmation'), findsOneWidget);
      expect(find.text('Send lot to website'), findsOneWidget);
      expect(find.text('Simulate Recycler Confirmation (Demo)'), findsNothing);
      expect(find.text('Handover Confirmed'), findsNothing);
    });

    testWidgets('4. Payment method chips Cash and UPI are available on PIN screen', (tester) async {
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

      await tester.pumpWidget(buildTestWidget(initialHandover: testHandover));
      await tester.pumpAndSettle();

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Scan QR'), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);

      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('UTR'), findsOneWidget);
    });

    testWidgets('5. PIN screen waits for website verification and does not re-ask recycler or weight', (tester) async {
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
            lot: EWasteLot(
              id: 'lot_test_005',
              categoryId: 'pcb_motherboard',
              categoryName: 'Motherboard / PCB',
              weightKg: 5.0,
              condition: 'average',
              estimatedMinPrice: 1200,
              estimatedMaxPrice: 1600,
              status: 'READY_FOR_HANDOVER',
              syncStatus: AppConstants.syncPending,
              createdAt: DateTime.now(),
            ),
            initialHandover: testHandover,
            handoverRepository: handoverRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Handover to Recycler'), findsNothing);
      expect(find.text('Select Authorized Recycler'), findsNothing);
      expect(find.text('Enter Weight (kg)'), findsNothing);
      expect(find.textContaining('website'), findsWidgets);
      expect(find.text('ORG'), findsNothing);
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
    });
  });
}
