import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/transaction.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/screens/home/home_screen.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/widgets/kabadiwala_logo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

class FakeLotRepository extends LotRepository {
  final List<EWasteLot> lots;
  FakeLotRepository({this.lots = const []});

  @override
  Future<List<EWasteLot>> getLots() async => lots;
}

class FakeTransactionRepository extends TransactionRepository {
  final List<Transaction> transactions;
  FakeTransactionRepository({this.transactions = const []});

  @override
  Future<TransactionLedgerData> fetchTransactions({bool forceRefresh = false}) async {
    return TransactionLedgerData(
      transactions: transactions,
      isOffline: true,
      lastUpdated: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeLotRepository fakeLotRepository;
  late FakeTransactionRepository fakeTransactionRepository;

  final sampleLot = EWasteLot(
    id: 'test_lot_1',
    categoryId: 'pcb',
    categoryName: 'Motherboard / PCB',
    weightKg: 5.0,
    condition: 'good',
    estimatedMinPrice: 1200.0,
    estimatedMaxPrice: 1450.0,
    status: 'READY_FOR_HANDOVER',
    syncStatus: AppConstants.syncPending,
    createdAt: DateTime.now(),
  );

  setUp(() {
    ConnectivityService.instance.setMockIsConnected(false);
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: inMemoryDatabasePath);
    fakeLotRepository = FakeLotRepository(lots: [sampleLot]);
    fakeTransactionRepository = FakeTransactionRepository();
  });

  tearDown(() async {
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
  });

  Widget buildTestApp({Locale locale = const Locale('en', '')}) {
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
      routes: {
        '/': (context) => HomeScreen(
              onLanguageChanged: (_) {},
              currentLocale: locale,
              lotRepository: fakeLotRepository,
              transactionRepository: fakeTransactionRepository,
            ),
        '/create-lot': (context) => Scaffold(
              appBar: AppBar(title: const Text('Create Lot')),
              body: const Text('CREATE_LOT_SCREEN'),
            ),
        '/recyclers': (context) => Scaffold(
              appBar: AppBar(title: const Text('Recyclers')),
              body: const Text('RECYCLER_MATCHING_SCREEN'),
            ),
        '/earnings': (context) => Scaffold(
              appBar: AppBar(title: const Text('Earnings')),
              body: const Text('EARNINGS_SCREEN'),
            ),
        '/prices': (context) => Scaffold(
              appBar: AppBar(title: const Text('Price Board')),
              body: const Text('PRICE_BOARD_SCREEN'),
            ),
        '/recycler-handover': (context) => Scaffold(
              appBar: AppBar(title: const Text('Handover')),
              body: const Text('HANDOVER_SCREEN'),
            ),
        '/safety': (context) => Scaffold(
              appBar: AppBar(title: const Text('Safety Guidance')),
              body: const Text('SAFETY_SCREEN'),
            ),
        '/notifications': (context) => Scaffold(
              appBar: AppBar(title: const Text('Notifications')),
              body: const Text('NOTIFICATIONS_SCREEN'),
            ),
      },
      initialRoute: '/',
    );
  }

  group('Navigation & Drawer Restructuring Tests', () {
    testWidgets('Header layout has hamburger menu, compact title, and no logo in AppBar title', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify AppBar exists
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify hamburger icon is present in AppBar leading
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Verify Notification bell and Language selector exist
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);

      // Verify AppBar title is just Text without KabadiwalaLogo in AppBar
      final appBar = tester.widget<AppBar>(appBarFinder);
      expect(appBar.title, isA<Text>());

      // KabadiwalaLogo should NOT be inside AppBar
      expect(find.descendant(of: appBarFinder, matching: find.byType(KabadiwalaLogo)), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Bottom navigation contains exactly 4 destinations and no "More" tab', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final bottomNavBarFinder = find.byType(BottomNavigationBar);
      expect(bottomNavBarFinder, findsOneWidget);

      final bottomNavBar = tester.widget<BottomNavigationBar>(bottomNavBarFinder);
      expect(bottomNavBar.items.length, equals(4));

      // Check labels: Home, Lots, Recyclers, Earnings
      expect(bottomNavBar.items[0].label, equals('Home'));
      expect(bottomNavBar.items[1].label, equals('Lots'));
      expect(bottomNavBar.items[2].label, equals('Recyclers'));
      expect(bottomNavBar.items[3].label, equals('Earnings'));

      // Confirm no "More" tab
      final hasMore = bottomNavBar.items.any((item) => item.label?.toLowerCase() == 'more');
      expect(hasMore, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Tapping hamburger opens side drawer with all 10 items and header logo', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Drawer is closed initially
      expect(find.byType(Drawer), findsNothing);

      // Tap hamburger menu
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Drawer is now open
      expect(find.byType(Drawer), findsOneWidget);

      // Drawer header contains small logo
      expect(find.descendant(of: find.byType(Drawer), matching: find.byType(KabadiwalaLogo)), findsOneWidget);

      // Drawer items exist
      expect(find.text('Home'), findsWidgets);
      expect(find.text('My Lots'), findsOneWidget);
      expect(find.text('Find Recycler'), findsWidgets);
      expect(find.text('Earnings'), findsWidgets);
      expect(find.text('Price Board'), findsWidgets);
      expect(find.text('Handover'), findsOneWidget);
      expect(find.text('Safety Guidance'), findsWidgets);
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('About / App Info'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Drawer items navigate to respective routes', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // 1. Open drawer & Tap "Find Recycler"
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Find Recycler'));
      await tester.pumpAndSettle();
      expect(find.text('RECYCLER_MATCHING_SCREEN'), findsOneWidget);

      // Pop back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 2. Open drawer & Tap "Price Board"
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Price Board'));
      await tester.pumpAndSettle();
      expect(find.text('PRICE_BOARD_SCREEN'), findsOneWidget);

      // Pop back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 3. Open drawer & Tap "Safety Guidance"
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Safety Guidance'));
      await tester.pumpAndSettle();
      expect(find.text('SAFETY_SCREEN'), findsOneWidget);

      // Pop back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 4. Open drawer & Tap "Handover"
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Handover'));
      await tester.pumpAndSettle();
      expect(find.text('HANDOVER_SCREEN'), findsOneWidget);

      // Pop back to home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // 5. Open drawer & Tap "About / App Info"
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'About / App Info'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.textContaining('SIH26229'), findsNothing);
      expect(find.text('What you can do'), findsOneWidget);
      expect(find.text('Works Offline'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Bottom navigation items navigate to respective routes', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap Lots in bottom navigation
      await tester.tap(find.text('Lots'));
      await tester.pumpAndSettle();
      expect(find.text('CREATE_LOT_SCREEN'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Tap Recyclers in bottom navigation
      await tester.tap(find.text('Recyclers'));
      await tester.pumpAndSettle();
      expect(find.text('RECYCLER_MATCHING_SCREEN'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Tap Earnings in bottom navigation
      await tester.tap(find.text('Earnings').last);
      await tester.pumpAndSettle();
      expect(find.text('EARNINGS_SCREEN'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Drawer renders properly in Hindi and Marathi', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Test Hindi
      await tester.pumpWidget(buildTestApp(locale: const Locale('hi', '')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('कबाड़ीवाला कनेक्ट'), findsWidgets);
      expect(find.text('मेरा माल'), findsOneWidget);
      expect(find.text('रिसायकलर खोजें'), findsWidgets);
      expect(find.text('भाव बोर्ड'), findsWidgets);
      expect(find.text('सुरक्षा मार्गदर्शन'), findsWidgets);

      await tester.tap(find.widgetWithText(ListTile, 'होम'));
      await tester.pumpAndSettle();

      // Test Marathi
      await tester.pumpWidget(buildTestApp(locale: const Locale('mr', '')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('कबाडीवाला कनेक्ट'), findsWidgets);
      expect(find.text('माझा माल'), findsOneWidget);
      expect(find.text('रिसायकलर शोधा'), findsWidgets);
      expect(find.text('दर फलक'), findsWidgets);
      expect(find.text('सुरक्षा मार्गदर्शन'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
