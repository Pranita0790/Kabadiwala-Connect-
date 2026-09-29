import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/transaction.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/screens/earnings/earnings_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/widgets/transaction_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late ConnectivityService connectivityService;
  late MockApiService mockApiService;
  late TransactionRepository transactionRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_earnings_test_');
    dbPath = '${tempDir.path}/test_earnings.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;

    connectivityService = ConnectivityService();
    mockApiService = MockApiService()..delay = Duration.zero;

    transactionRepository = TransactionRepository(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
    );
  });

  tearDown(() async {
    connectivityService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Earnings Ledger Repository & Data Flow Tests', () {
    test('1. Empty transaction list test', () async {
      connectivityService.setMockIsConnected(false);

      final result = await transactionRepository.fetchTransactions();
      expect(result.transactions, isEmpty);
      expect(result.totalEarnings, equals(0.0));
      expect(result.currentMonthEarnings, equals(0.0));
      expect(result.pendingEarnings, equals(0.0));
      expect(result.isOffline, isTrue);
    });

    test('2. Multiple transactions: Online fetch, SQLite caching & calculations', () async {
      connectivityService.setMockIsConnected(true);

      final result = await transactionRepository.fetchTransactions();
      expect(result.isOffline, isFalse);
      expect(result.transactions.length, equals(4));

      // Paid transactions in mock: tx_101 (3400), tx_102 (4600), tx_104 (2200) -> Total Paid = 10,200
      expect(result.totalEarnings, equals(10200.0));

      // Current month paid transactions: tx_101 (3400) + tx_102 (4600) -> Month Paid = 8,000
      expect(result.currentMonthEarnings, equals(8000.0));

      // Pending transactions: tx_103 (2250)
      expect(result.pendingEarnings, equals(2250.0));

      // Verify cached into SQLite
      final cached = await dbService.getTransactions();
      expect(cached.length, equals(4));
    });

    test('3. Offline mode test: Reading previously cached transactions without internet', () async {
      // First fetch while online to populate SQLite
      connectivityService.setMockIsConnected(true);
      await transactionRepository.fetchTransactions();

      // Go offline
      connectivityService.setMockIsConnected(false);
      expect(await connectivityService.isConnected(), isFalse);

      // Read ledger offline
      final offlineResult = await transactionRepository.fetchTransactions();
      expect(offlineResult.isOffline, isTrue);
      expect(offlineResult.transactions.length, equals(4));
      expect(offlineResult.totalEarnings, equals(10200.0));
      expect(offlineResult.currentMonthEarnings, equals(8000.0));
    });
  });

  group('TransactionCard & UI Widget Tests', () {
    testWidgets('TransactionCard displays material, weight, recycler, amount, date, and payment status',
        (WidgetTester tester) async {
      final tx = Transaction(
        id: 'tx_unit_01',
        lotId: 'lot_unit_01',
        recyclerId: 'Nagpur Formal Dismantlers',
        quotedPrice: 3400.0,
        finalPrice: 3500.0,
        paymentStatus: 'PAID',
        handoverStatus: 'COMPLETED',
        createdAt: DateTime(2026, 9, 27, 14, 30),
        categoryName: 'Motherboard / PCB',
        weightKg: 12.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
          ],
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Material & Weight
      expect(find.text('Motherboard / PCB'), findsOneWidget);
      expect(find.text('12.5 kg'), findsOneWidget);

      // Verify Recycler
      expect(find.textContaining('Nagpur Formal Dismantlers'), findsOneWidget);

      // Verify Final Amount
      expect(find.text('₹3,500'), findsOneWidget);

      // Verify Payment Status Paid
      expect(find.text('Paid'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('TransactionCard displays Pending status badge appropriately',
        (WidgetTester tester) async {
      final pendingTx = Transaction(
        id: 'tx_unit_02',
        lotId: 'lot_unit_02',
        recyclerId: 'CleanTech Recyclers',
        finalPrice: 1800.0,
        paymentStatus: 'PENDING',
        categoryName: 'Batteries',
        weightKg: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
          ],
          home: Scaffold(
            body: TransactionCard(transaction: pendingTx),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Batteries'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('EarningsScreen renders summary cards and handles localization (Hindi)',
        (WidgetTester tester) async {
      connectivityService.setMockIsConnected(true);

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
          home: EarningsScreen(repository: transactionRepository),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify Hindi summary labels
      expect(find.text('कुल कमाई'), findsOneWidget);
      expect(find.text('इस महीने की कमाई'), findsOneWidget);
    });
  });
}
