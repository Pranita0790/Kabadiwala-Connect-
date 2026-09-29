import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/recycler.dart';
import 'package:kabadiwala_connect/repositories/recycler_repository.dart';
import 'package:kabadiwala_connect/screens/recycler/recycler_matching_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late ConnectivityService connectivityService;
  late MockApiService apiService;
  late RecyclerRepository recyclerRepository;

  final sampleRecyclers = [
    const Recycler(
      id: 'rec_01',
      name: 'EcoRecycle Maharashtra',
      address: 'Plot 42, MIDC Hingna Industrial Area, Nagpur',
      acceptedCategories: ['pcb', 'copper_wire', 'battery', 'display', 'appliances', 'mixed'],
      distanceKm: 2.4,
      isAuthorized: true,
      rating: 4.8,
      contactPhone: '+91 98230 11223',
      latitude: 21.1458,
      longitude: 79.0882,
      indicativePrice: 320.0,
      unit: 'kg',
      isDemo: true,
    ),
    const Recycler(
      id: 'rec_02',
      name: 'GreenEarth Formal Dismantlers',
      address: 'Sector 8, Butibori Industrial Estate, Nagpur',
      acceptedCategories: ['pcb', 'copper_wire', 'display', 'mixed'],
      distanceKm: 4.8,
      isAuthorized: true,
      rating: 4.6,
      contactPhone: '+91 94221 44556',
      latitude: 21.1120,
      longitude: 79.0510,
      indicativePrice: 310.0,
      unit: 'kg',
      isDemo: true,
    ),
    const Recycler(
      id: 'rec_03',
      name: 'Central India Metal Refiners',
      address: 'Ghat Road, Cotton Market Yard, Nagpur',
      acceptedCategories: ['copper_wire', 'battery', 'appliances'],
      distanceKm: 7.2,
      isAuthorized: true,
      rating: 4.3,
      contactPhone: '+91 98900 77889',
      latitude: 21.1680,
      longitude: 79.1120,
      indicativePrice: 620.0,
      unit: 'kg',
      isDemo: true,
    ),
    const Recycler(
      id: 'rec_04',
      name: 'Vidarbha Safe E-Waste Center',
      address: 'Near Old Toll Plaza, Kamptee Road, Nagpur',
      acceptedCategories: ['pcb', 'battery', 'display'],
      distanceKm: 9.5,
      isAuthorized: false,
      rating: 4.0,
      contactPhone: '+91 97654 33221',
      latitude: 21.2010,
      longitude: 79.1350,
      indicativePrice: 280.0,
      unit: 'kg',
      isDemo: true,
    ),
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_recycler_test_');
    dbPath = '${tempDir.path}/test_kabadiwala_recycler.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);

    connectivityService = ConnectivityService.instance;
    connectivityService.setMockIsConnected(true);

    apiService = MockApiService();
    recyclerRepository = RecyclerRepository(
      dbService: DatabaseService.instance,
      apiService: apiService,
      connectivityService: connectivityService,
    );
  });

  tearDown(() async {
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestWidget({
    EWasteLot? lot,
    String? selectedCategory,
    List<Recycler>? initialRecyclers,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
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
      home: RecyclerMatchingScreen(
        lot: lot,
        selectedCategory: selectedCategory,
        initialRecyclers: initialRecyclers,
        recyclerRepository: recyclerRepository,
      ),
    );
  }

  group('RecyclerMatchingScreen Full Implementation & Verification Tests', () {
    testWidgets('1. Recycler results are actually visible with 4 match cards rendered', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(initialRecyclers: sampleRecyclers));
      await tester.pumpAndSettle();

      // Verify Header badges
      expect(find.text('DEMO DATA'), findsOneWidget);
      expect(find.textContaining('4 Matches Found'), findsOneWidget);
      expect(find.textContaining('Location permission unavailable'), findsOneWidget);

      // Verify all 4 recyclers are rendered as cards
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.text('GreenEarth Formal Dismantlers'), findsOneWidget);
      expect(find.text('Central India Metal Refiners'), findsOneWidget);
      expect(find.text('Vidarbha Safe E-Waste Center'), findsOneWidget);

      // Verify pricing and distance details are visible
      expect(find.text('2.4 km away'), findsOneWidget);
      expect(find.text('320/kg'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('Authorized Recycler'), findsWidgets);
    });

    testWidgets('2. Map/Radar toggle switches between views and displays radar elements', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(initialRecyclers: sampleRecyclers));
      await tester.pumpAndSettle();

      // Toggle to Map View via AppBar button
      await tester.tap(find.byIcon(Icons.map_rounded));
      await tester.pumpAndSettle();

      // Radar should be visible with central You marker and distance nodes
      expect(find.text('You'), findsOneWidget);
      expect(find.text('2.4km'), findsOneWidget);
      expect(find.text('4.8km'), findsOneWidget);

      // Bottom quick preview card for selected recycler
      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);

      // Toggle back to List view via segmented button
      await tester.tap(find.text('List View'));
      await tester.pumpAndSettle();

      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.text('GreenEarth Formal Dismantlers'), findsOneWidget);
    });

    testWidgets('3. Tapping View Details opens modal bottom sheet with material tags and handover button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(initialRecyclers: sampleRecyclers));
      await tester.pumpAndSettle();

      // Tap View Details on the first recycler
      final viewDetailsButton = find.text('View Details').first;
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Bottom sheet should display accepted materials and Proceed to Handover button
      expect(find.text('Accepted Materials'), findsOneWidget);
      expect(find.text('Proceed to Handover'), findsOneWidget);
      expect(find.text('COPPER WIRE'), findsWidgets);
      expect(find.text('BATTERY'), findsWidgets);
    });

    testWidgets('4. Empty state is cleanly rendered with helpful guidance when 0 matches', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(initialRecyclers: []));
      await tester.pumpAndSettle();

      expect(find.text('No matching recyclers found'), findsOneWidget);
      expect(find.text('Try selecting a different material category or check back later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('5. Offline database fetching works seamlessly without internet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed local SQLite
      await tester.runAsync(() async {
        await DatabaseService.instance.insertRecyclers(sampleRecyclers);
      });
      connectivityService.setMockIsConnected(false);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      expect(find.text('EcoRecycle Maharashtra'), findsOneWidget);
      expect(find.text('GreenEarth Formal Dismantlers'), findsOneWidget);
      expect(find.textContaining('4 Matches Found'), findsOneWidget);
    });

    testWidgets('6. Hindi and Marathi localization render accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Hindi
      await tester.pumpWidget(buildTestWidget(
        initialRecyclers: sampleRecyclers,
        locale: const Locale('hi'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('रिसायकलर मैचिंग'), findsOneWidget);
      expect(find.textContaining('मैच मिले'), findsOneWidget);
      expect(find.text('नजदीकी रिसायकलर'), findsOneWidget);

      // Marathi
      await tester.pumpWidget(buildTestWidget(
        initialRecyclers: sampleRecyclers,
        locale: const Locale('mr'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('रिसायकलर जुळणी'), findsOneWidget);
      expect(find.textContaining('जुळणी सापडली'), findsOneWidget);
      expect(find.text('जवळचे रिसायकलर'), findsOneWidget);
    });
  });
}
