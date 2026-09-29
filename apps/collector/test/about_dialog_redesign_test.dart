import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/screens/home/home_screen.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/widgets/kabadiwala_logo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

class FakeLotRepo extends LotRepository {
  final List<EWasteLot> lots;
  FakeLotRepo({this.lots = const []});
  @override
  Future<List<EWasteLot>> getLots() async => lots;
}

class FakeTxRepo extends TransactionRepository {
  @override
  Future<TransactionLedgerData> fetchTransactions({bool forceRefresh = false}) async {
    return TransactionLedgerData(
      transactions: const [],
      isOffline: true,
      lastUpdated: DateTime.now(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeLotRepo fakeLotRepo;
  late FakeTxRepo fakeTxRepo;

  setUp(() {
    ConnectivityService.instance.setMockIsConnected(false);
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: inMemoryDatabasePath);
    fakeLotRepo = FakeLotRepo();
    fakeTxRepo = FakeTxRepo();
  });

  tearDown(() async {
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
  });

  Widget buildAboutTestApp({Locale locale = const Locale('en', '')}) {
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
      home: HomeScreen(
        currentLocale: locale,
        onLanguageChanged: (_) {},
        lotRepository: fakeLotRepo,
        transactionRepository: fakeTxRepo,
      ),
    );
  }

  group('Redesigned About / App Info Dialog Tests', () {
    testWidgets('Opens redesigned About dialog from drawer and validates all sections (English)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildAboutTestApp());
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Tap About in drawer
      await tester.tap(find.widgetWithText(ListTile, 'About / App Info'));
      await tester.pumpAndSettle();

      // 1. Dialog & Branding Header
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(KabadiwalaLogo)), findsOneWidget);
      expect(find.text('Kabadiwala Connect'), findsWidgets);
      expect(find.text('Connecting Collectors • Fair Prices • Formal Recycling'), findsOneWidget);

      // 2. Short App Description
      expect(
        find.textContaining('Kabadiwala Connect helps waste collectors identify recyclable materials'),
        findsOneWidget,
      );

      // 3. "What you can do" Key Features (6 rows)
      expect(find.text('What you can do'), findsOneWidget);
      expect(find.text('Material Management'), findsOneWidget);
      expect(find.text('Price Board'), findsWidgets);
      expect(find.text('Find Recyclers'), findsOneWidget);
      expect(find.text('Safe Handover'), findsOneWidget);
      expect(find.text('Safety Guidance'), findsWidgets);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Earnings Ledger')), findsOneWidget);

      // 4. Offline-First Highlight
      expect(find.text('Works Offline'), findsOneWidget);
      expect(
        find.text('Your records are stored locally and synchronized when connectivity is available.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // 5. Languages
      expect(find.text('Available in English • हिन्दी • मराठी'), findsOneWidget);

      // 6. Dynamic Version (without SIH26229)
      expect(find.text('Version ${AppConstants.appVersion}'), findsOneWidget);

      // 7. SIH26229 MUST NOT exist anywhere
      expect(find.textContaining('SIH26229'), findsNothing);

      // 8. Close Button
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('About dialog renders accurately in Hindi without SIH26229', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildAboutTestApp(locale: const Locale('hi', '')));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Tap About in drawer
      await tester.tap(find.widgetWithText(ListTile, 'कबाड़ीवाला कनेक्ट के बारे में'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('कबाड़ीवाला कनेक्ट'), findsWidgets);
      expect(find.text('कलेक्टर्स को जोड़ना • उचित भाव • औपचारिक रिसायकलिंग'), findsOneWidget);
      expect(find.text('आप क्या कर सकते हैं'), findsOneWidget);
      expect(find.text('सामग्री प्रबंधन'), findsOneWidget);
      expect(find.text('ऑफ़लाइन काम करता है'), findsOneWidget);
      expect(find.text('English • हिन्दी • मराठी में उपलब्ध'), findsOneWidget);
      expect(find.text('संस्करण ${AppConstants.appVersion}'), findsOneWidget);
      expect(find.textContaining('SIH26229'), findsNothing);

      // Close dialog
      await tester.tap(find.text('बंद करें'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('About dialog renders accurately in Marathi without SIH26229', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildAboutTestApp(locale: const Locale('mr', '')));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Tap About in drawer
      await tester.tap(find.widgetWithText(ListTile, 'कबाडीवाला कनेक्टबद्दल'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('कबाडीवाला कनेक्ट'), findsWidgets);
      expect(find.text('कलेक्टर्सना जोडणे • योग्य दर • अधिकृत रिसायकलिंग'), findsOneWidget);
      expect(find.text('तुम्ही काय करू शकता'), findsOneWidget);
      expect(find.text('सामग्री व्यवस्थापन'), findsOneWidget);
      expect(find.text('ऑफलाइन कार्य करते'), findsOneWidget);
      expect(find.text('English • हिन्दी • मराठी मध्ये उपलब्ध'), findsOneWidget);
      expect(find.text('आवृत्ती ${AppConstants.appVersion}'), findsOneWidget);
      expect(find.textContaining('SIH26229'), findsNothing);

      // Close dialog
      await tester.tap(find.text('बंद करा'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
