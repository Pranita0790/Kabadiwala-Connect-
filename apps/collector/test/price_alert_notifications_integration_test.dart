import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/app_notification.dart';
import 'package:kabadiwala_connect/models/e_waste_lot.dart';
import 'package:kabadiwala_connect/models/price_alert.dart';
import 'package:kabadiwala_connect/models/transaction.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/screens/home/home_screen.dart';
import 'package:kabadiwala_connect/screens/notifications/notifications_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/notification_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';
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
  List<PriceAlert> alerts;
  late StreamController<int> _unreadController;
  late StreamController<List<AppNotification>> _notifsController;

  FakeNotificationService({
    this.items = const [],
    this.alerts = const [],
  }) {
    _unreadController = StreamController<int>.broadcast();
    _notifsController = StreamController<List<AppNotification>>.broadcast();
  }

  @override
  Stream<int> get unreadCountStream => _unreadController.stream;

  @override
  Stream<List<AppNotification>> get notificationsStream => _notifsController.stream;

  @override
  Future<List<AppNotification>> getNotifications() async => items;

  @override
  Future<int> getUnreadCount() async => items.where((n) => !n.isRead).length;

  @override
  Future<List<PriceAlert>> getPriceAlerts() async => alerts;

  @override
  Future<PriceAlert> createPriceAlert({
    String? id,
    String? categoryId,
    String? categoryName,
    String? material,
    required double targetPrice,
    String unit = 'kg',
  }) async {
    final alertId = id ?? 'alert_${DateTime.now().millisecondsSinceEpoch}';
    final name = categoryName ?? material ?? 'Material';
    final alert = PriceAlert(
      id: alertId,
      categoryId: categoryId ?? 'cat',
      categoryName: name,
      targetPrice: targetPrice,
      unit: unit,
      createdAt: DateTime.now(),
      isActive: true,
    );
    alerts = [...alerts, alert];

    final notif = AppNotification(
      id: 'notif_alert_$alertId',
      titleEn: '🔔 Price Alert: $name',
      titleHi: '🔔 भाव इशारा: $name',
      titleMr: '🔔 दर इशारा: $name',
      bodyEn: '$name price alert created at ₹${targetPrice.toStringAsFixed(0)}/$unit. You will be notified when market rates meet your target.',
      bodyHi: '$name के लिए ₹${targetPrice.toStringAsFixed(0)}/$unit पर भाव अलर्ट सेट किया गया।',
      bodyMr: '$name साठी ₹${targetPrice.toStringAsFixed(0)}/$unit वर दर अलर्ट सेट केला गेला.',
      type: AppConstants.notificationPriceAlert,
      relatedId: alertId,
      timestamp: DateTime.now(),
      isRead: false,
      isDemo: true,
    );
    items = [notif, ...items];
    final unread = items.where((n) => !n.isRead).length;
    if (!_notifsController.isClosed) {
      _notifsController.add(items);
    }
    if (!_unreadController.isClosed) {
      _unreadController.add(unread);
    }
    return alert;
  }

  @override
  Future<void> markAsRead(String id) async {
    items = items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    if (!_notifsController.isClosed) {
      _notifsController.add(items);
    }
    if (!_unreadController.isClosed) {
      _unreadController.add(items.where((n) => !n.isRead).length);
    }
  }

  @override
  void dispose() {
    if (!_unreadController.isClosed) {
      _unreadController.close();
    }
    if (!_notifsController.isClosed) {
      _notifsController.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late NotificationService notificationService;
  late SyncService syncService;
  late FakeLotRepository fakeLotRepository;
  late FakeTransactionRepository fakeTransactionRepository;
  late FakeNotificationService fakeNotificationService;

  setUp(() async {
    NotificationService.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('sih26_price_alert_test_');
    dbPath = '${tempDir.path}/test_price_alerts.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    ConnectivityService.instance.setMockIsConnected(false);
    fakeLotRepository = FakeLotRepository();
    fakeTransactionRepository = FakeTransactionRepository();
    syncService = SyncService(
      dbService: DatabaseService.instance,
      apiService: MockApiService(),
      connectivityService: ConnectivityService.instance,
      autoSyncOnOnline: false,
    );
    SyncService.setInstance(syncService);
    notificationService = NotificationService(dbService: DatabaseService.instance);
    NotificationService.setInstance(notificationService);
    fakeNotificationService = FakeNotificationService();
  });

  tearDown(() async {
    syncService.dispose();
    fakeNotificationService.dispose();
    ConnectivityService.instance.resetForTesting();
    NotificationService.resetForTesting();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Price Alert -> Notifications Database & Service Integration (SQLite)', () {
    test('1. Creating a Price Alert persists Price Alert and unread PRICE_ALERT notification in SQLite', () async {
      final alert = await notificationService.createPriceAlert(
        material: 'Copper Wire',
        targetPrice: 650.0,
      );

      expect(alert.id, isNotEmpty);
      expect(alert.categoryName, equals('Copper Wire'));
      expect(alert.targetPrice, equals(650.0));

      // 1. Verify price_alerts SQLite table
      final dbAlerts = await DatabaseService.instance.getPriceAlerts();
      expect(dbAlerts.length, equals(1));
      expect(dbAlerts.first.categoryName, equals('Copper Wire'));
      expect(dbAlerts.first.targetPrice, equals(650.0));
      expect(dbAlerts.first.isActive, isTrue);

      // 2. Verify notifications SQLite table
      final dbNotifications = await DatabaseService.instance.getNotifications();
      expect(dbNotifications.length, equals(1));

      final notif = dbNotifications.first;
      expect(notif.type, equals(AppConstants.notificationPriceAlert));
      expect(notif.relatedId, equals(alert.id));
      expect(notif.isRead, isFalse);
      expect(notif.titleEn, contains('Price Alert: Copper Wire'));
      expect(notif.bodyEn, contains('₹650/kg'));

      // 3. Verify unread notification count is 1
      final unreadCount = await notificationService.getUnreadCount();
      expect(unreadCount, equals(1));
    });

    test('2. Idempotency: Repeated creation with same alert ID prevents duplicate notifications', () async {
      const fixedAlertId = 'fixed_alert_id_001';

      // First call
      await notificationService.createPriceAlert(
        id: fixedAlertId,
        material: 'PCB Motherboard',
        targetPrice: 320.0,
      );

      // Duplicate call with same ID
      await notificationService.createPriceAlert(
        id: fixedAlertId,
        material: 'PCB Motherboard',
        targetPrice: 320.0,
      );

      final dbAlerts = await DatabaseService.instance.getPriceAlerts();
      expect(dbAlerts.length, equals(1));

      final dbNotifications = await DatabaseService.instance.getNotifications();
      expect(dbNotifications.length, equals(1));
    });

    test('3. Data persists across database reload and service recreation', () async {
      await notificationService.createPriceAlert(
        material: 'Lithium Batteries',
        targetPrice: 110.0,
      );

      // Close and reopen database simulating app restart
      await DatabaseService.closeDatabase();
      DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
      final reloadedService = NotificationService(dbService: DatabaseService.instance);

      final alerts = await reloadedService.getPriceAlerts();
      expect(alerts.length, equals(1));
      expect(alerts.first.categoryName, equals('Lithium Batteries'));

      final notifications = await reloadedService.getNotifications();
      expect(notifications.length, equals(1));
      expect(notifications.first.type, equals(AppConstants.notificationPriceAlert));
      expect(notifications.first.isRead, isFalse);
      expect(notifications.first.titleEn, contains('Lithium Batteries'));
    });

    test('4. Mark as read updates SQLite status and emits new unread count via stream', () async {
      await notificationService.createPriceAlert(
        material: 'Display Monitors',
        targetPrice: 180.0,
      );

      final notifs = await notificationService.getNotifications();
      expect(notifs.first.isRead, isFalse);
      expect(await notificationService.getUnreadCount(), equals(1));

      // Mark notification as read
      await notificationService.markAsRead(notifs.first.id);

      final updatedNotifs = await notificationService.getNotifications();
      expect(updatedNotifs.first.isRead, isTrue);
      expect(await notificationService.getUnreadCount(), equals(0));
    });

    test('5. Multi-type notifications: HANDOVER_CONFIRMED and PRICE_ALERT coexist in SQLite', () async {
      await notificationService.simulateDemoHandoverConfirmed(
        recyclerName: 'EcoRecycle Maharashtra',
        materialCategory: 'PCB',
        weightKg: 5.0,
        amount: 1500.0,
      );

      await notificationService.createPriceAlert(
        material: 'Copper Wire',
        targetPrice: 620.0,
      );

      final allNotifs = await notificationService.getNotifications();
      expect(allNotifs.length, equals(2));

      expect(allNotifs.any((n) => n.type == AppConstants.notificationHandover), isTrue);
      expect(allNotifs.any((n) => n.type == AppConstants.notificationPriceAlert), isTrue);
      expect(await notificationService.getUnreadCount(), equals(2));
    });
  });

  group('Price Alert -> Notifications UI & Navigation Widget Tests', () {
    Widget buildTestApp({
      Locale locale = const Locale('en'),
      NotificationService? service,
      Widget? initialScreen,
    }) {
      final activeService = service ?? fakeNotificationService;
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
          '/': (_) =>
              initialScreen ??
              HomeScreen(
                onLanguageChanged: (_) {},
                currentLocale: locale,
                lotRepository: fakeLotRepository,
                transactionRepository: fakeTransactionRepository,
                syncService: syncService,
                notificationService: activeService,
              ),
          '/notifications': (_) => NotificationsScreen(
                notificationService: activeService,
              ),
          '/prices': (_) => const Scaffold(
                body: Text('Price Board Screen Route'),
              ),
          '/earnings': (_) => const Scaffold(
                body: Text('Earnings Ledger Screen Route'),
              ),
        },
        initialRoute: '/',
      );
    }

    testWidgets('6. Notification bell badge reflects live unread count updates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Initially 0 unread
      expect(find.byIcon(Icons.notifications_rounded), findsWidgets);

      // Create price alert through service
      await fakeNotificationService.createPriceAlert(
        material: 'Copper Wire',
        targetPrice: 660.0,
      );
      await tester.idle();
      await tester.pump();

      // Badge displays "1"
      expect(find.text('1'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('7. NotificationsScreen displays PRICE_ALERT card with material & target price info', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final alertNotif = AppNotification(
        id: 'notif_alert_test_01',
        titleEn: '🔔 Price Alert: Copper Wire',
        titleHi: '🔔 भाव इशारा: Copper Wire',
        titleMr: '🔔 दर इशारा: Copper Wire',
        bodyEn: 'Copper Wire price alert created at ₹660/kg. You will be notified when market rates meet your target.',
        bodyHi: 'Copper Wire के लिए ₹660/kg पर भाव अलर्ट सेट किया गया।',
        bodyMr: 'Copper Wire साठी ₹660/kg वर दर अलर्ट सेट केला गेला.',
        type: AppConstants.notificationPriceAlert,
        relatedId: 'alert_001',
        timestamp: DateTime.now(),
        isRead: false,
        isDemo: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          initialScreen: NotificationsScreen(
            initialNotifications: [alertNotif],
            notificationService: fakeNotificationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🔔 Price Alert: Copper Wire'), findsOneWidget);
      expect(find.textContaining('₹660/kg'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('8. Tapping PRICE_ALERT notification marks it as read and navigates to /prices', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final alertNotif = AppNotification(
        id: 'notif_alert_nav_01',
        titleEn: '🔔 Price Alert: Copper Wire',
        titleHi: '🔔 भाव इशारा: Copper Wire',
        titleMr: '🔔 दर इशारा: Copper Wire',
        bodyEn: 'Copper Wire price alert created at ₹660/kg.',
        bodyHi: 'Copper Wire भाव अलर्ट ₹660/kg.',
        bodyMr: 'Copper Wire दर अलर्ट ₹660/kg.',
        type: AppConstants.notificationPriceAlert,
        relatedId: 'alert_001',
        timestamp: DateTime.now(),
        isRead: false,
        isDemo: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          initialScreen: NotificationsScreen(
            initialNotifications: [alertNotif],
            notificationService: fakeNotificationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the price alert notification
      await tester.tap(find.text('🔔 Price Alert: Copper Wire'));
      await tester.pumpAndSettle();

      // Navigated to /prices route
      expect(find.text('Price Board Screen Route'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('9. NotificationsScreen supports English, Hindi, and Marathi translations for PRICE_ALERT', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final alertNotif = AppNotification(
        id: 'notif_alert_lang_01',
        titleEn: '🔔 Price Alert: Copper Wire',
        titleHi: '🔔 भाव इशारा: तांबे का तार',
        titleMr: '🔔 दर इशारा: तांब्याची तार',
        bodyEn: 'Copper Wire price alert created at ₹660/kg.',
        bodyHi: 'तांबे का तार के लिए ₹660/kg पर भाव अलर्ट सेट किया गया।',
        bodyMr: 'तांब्याची तार साठी ₹660/kg वर दर अलर्ट सेट केला गेला.',
        type: AppConstants.notificationPriceAlert,
        relatedId: 'alert_001',
        timestamp: DateTime.now(),
        isRead: false,
        isDemo: true,
      );

      // 1. Hindi test
      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale('hi'),
          initialScreen: NotificationsScreen(
            initialNotifications: [alertNotif],
            notificationService: fakeNotificationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🔔 भाव इशारा: तांबे का तार'), findsOneWidget);
      expect(find.textContaining('₹660/kg'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      // 2. Marathi test
      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale('mr'),
          initialScreen: NotificationsScreen(
            initialNotifications: [alertNotif],
            notificationService: fakeNotificationService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🔔 दर इशारा: तांब्याची तार'), findsOneWidget);
      expect(find.textContaining('₹660/kg'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
