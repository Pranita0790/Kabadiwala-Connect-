import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/app_notification.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/transaction.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/screens/home/home_screen.dart';
import 'package:kabadiwala_connect/screens/notifications/notifications_screen.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/notification_service.dart';
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

class FakeNotificationService extends NotificationService {
  List<AppNotification> items;
  bool shouldThrow;
  bool wasMarkAsReadCalled = false;
  bool wasMarkAllAsReadCalled = false;

  FakeNotificationService({
    this.items = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<AppNotification>> getNotifications() async {
    if (shouldThrow) {
      throw Exception('Database query failed for notifications');
    }
    return items;
  }

  @override
  Future<int> getUnreadCount() async {
    if (shouldThrow) return 0;
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    wasMarkAsReadCalled = true;
    items = items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  @override
  Future<void> markAllAsRead() async {
    wasMarkAllAsReadCalled = true;
    items = items.map((n) => n.copyWith(isRead: true)).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FakeNotificationService fakeService;
  late FakeLotRepository fakeLotRepository;
  late FakeTransactionRepository fakeTransactionRepository;

  setUp(() {
    ConnectivityService.instance.setMockIsConnected(false);
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: inMemoryDatabasePath);
    fakeLotRepository = FakeLotRepository();
    fakeTransactionRepository = FakeTransactionRepository();
    fakeService = FakeNotificationService();
    NotificationService.setInstance(fakeService);
  });

  tearDown(() async {
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
  });

  Widget buildTestApp({
    Locale locale = const Locale('en', ''),
    Widget? homeWidget,
    FakeNotificationService? customService,
  }) {
    final service = customService ?? fakeService;

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
        '/': (context) =>
            homeWidget ??
            HomeScreen(
              onLanguageChanged: (_) {},
              currentLocale: locale,
              lotRepository: fakeLotRepository,
              transactionRepository: fakeTransactionRepository,
            ),
        '/notifications': (context) => NotificationsScreen(
              notificationService: service,
            ),
        '/earnings': (context) => const Scaffold(
              body: Text('EARNINGS_SCREEN'),
            ),
        '/prices': (context) => const Scaffold(
              body: Text('PRICE_BOARD_SCREEN'),
            ),
      },
      initialRoute: '/',
    );
  }

  final sampleHandoverNotification = AppNotification(
    id: 'notif_1',
    titleEn: 'Handover Confirmed',
    titleHi: 'हस्तांतरण संपन्न',
    titleMr: 'हस्तांतरण पूर्ण झाले',
    bodyEn: '₹2,400 received from Central Recycler',
    bodyHi: '₹2,400 सेंट्रल रिसायकलर से प्राप्त हुए',
    bodyMr: '₹2,400 सेंट्रल रिसायकलरकडून मिळाले',
    type: AppConstants.notificationTypeHandover,
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    isRead: false,
  );

  final samplePriceAlertNotification = AppNotification(
    id: 'notif_2',
    titleEn: 'Price Alert: Copper Wire',
    titleHi: 'भाव अलर्ट: तांबे का तार',
    titleMr: 'दर अलर्ट: तांब्याची तार',
    bodyEn: 'Market rate reached ₹720/kg (+8%)',
    bodyHi: 'बाजार भाव ₹720/किग्रा पहुंच गया है',
    bodyMr: 'बाजार दर ₹720/किलो पोहोचला आहे',
    type: AppConstants.notificationTypePriceAlert,
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    isRead: true,
  );

  group('Notifications Screen & Navigation Bugfix Verification', () {
    testWidgets('1. Empty notification state renders with icon, description, demo cards and back button', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeService.items = [];

      await tester.pumpWidget(
        buildTestApp(
          homeWidget: NotificationsScreen(notificationService: fakeService),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Notifications'), findsOneWidget);

      // Verify Empty State elements
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.textContaining('You\'ll see updates here when:'), findsOneWidget);

      // Verify Demo cards are visible
      expect(find.text('Price Alert: Copper Wire'), findsOneWidget);
      expect(find.text('Handover Confirmed'), findsOneWidget);

      // Verify Back Arrow is present
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap Demo Price Alert -> Navigates to /prices
      await tester.tap(find.text('Price Alert: Copper Wire'));
      await tester.pumpAndSettle();
      expect(find.text('PRICE_BOARD_SCREEN'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('2. Notifications list renders items, unread indicators, and handles tap navigation', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeService.items = [sampleHandoverNotification, samplePriceAlertNotification];

      await tester.pumpWidget(
        buildTestApp(
          homeWidget: NotificationsScreen(notificationService: fakeService),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Notification titles
      expect(find.text('Handover Confirmed'), findsOneWidget);
      expect(find.text('Price Alert: Copper Wire'), findsOneWidget);

      // Verify messages
      expect(find.text('₹2,400 received from Central Recycler'), findsOneWidget);
      expect(find.text('Market rate reached ₹720/kg (+8%)'), findsOneWidget);

      // Verify Mark All Read button is present because notif_1 is unread
      expect(find.text('Mark All Read'), findsOneWidget);

      // Tap Handover notification -> Should navigate to /earnings
      await tester.tap(find.text('Handover Confirmed'));
      await tester.pumpAndSettle();

      expect(find.text('EARNINGS_SCREEN'), findsOneWidget);
      expect(fakeService.wasMarkAsReadCalled, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3. Service/Database failure displays clear error state with Retry button (no infinite freeze)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final errorService = FakeNotificationService(shouldThrow: true);

      await tester.pumpWidget(
        buildTestApp(
          homeWidget: NotificationsScreen(notificationService: errorService),
          customService: errorService,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Error state appears
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Unable to load notifications'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix error and tap Retry
      errorService.shouldThrow = false;
      errorService.items = [samplePriceAlertNotification];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Error is replaced with loaded notification
      expect(find.text('Price Alert: Copper Wire'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4. Home Notification Bell opens NotificationsScreen and Back Arrow returns to Home', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeService.items = [sampleHandoverNotification];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Verify on Home
      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);

      // Tap Notification Bell
      await tester.tap(find.byIcon(Icons.notifications_rounded));
      await tester.pumpAndSettle();

      // On Notifications Screen
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Handover Confirmed'), findsOneWidget);

      // Tap Back Arrow
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back on Home and Home is fully interactive
      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Create Lot'), findsOneWidget);
      expect(find.text('Price Board'), findsOneWidget);
      expect(find.text('Earnings Ledger'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5. Drawer Notifications tile opens NotificationsScreen and Back returns to Home', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Open Drawer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Tap Notifications in Drawer
      await tester.tap(find.widgetWithText(ListTile, 'Notifications'));
      await tester.pumpAndSettle();

      // On Notifications Screen
      expect(find.text('Notifications'), findsOneWidget);

      // Tap Back Arrow
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Back on Home
      expect(find.text('Kabadiwala Connect'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6. Notifications Screen renders properly in Hindi and Marathi', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeService.items = [sampleHandoverNotification, samplePriceAlertNotification];

      // Test Hindi
      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale('hi', ''),
          homeWidget: NotificationsScreen(notificationService: fakeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('सूचनाएं'), findsOneWidget);
      expect(find.text('हस्तांतरण संपन्न'), findsOneWidget);
      expect(find.text('भाव अलर्ट: तांबे का तार'), findsOneWidget);
      expect(find.text('सभी को पढ़ा हुआ चिह्नित करें'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      // Test Marathi
      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale('mr', ''),
          homeWidget: NotificationsScreen(notificationService: fakeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('सूचना'), findsOneWidget);
      expect(find.text('हस्तांतरण पूर्ण झाले'), findsOneWidget);
      expect(find.text('दर अलर्ट: तांब्याची तार'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
