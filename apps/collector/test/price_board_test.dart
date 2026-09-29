import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/models/price.dart';
import 'package:kabadiwala_connect/repositories/price_repository.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/audio_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/widgets/price_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late ConnectivityService connectivityService;
  late MockApiService mockApiService;
  late PriceRepository priceRepository;
  late AudioService audioService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_price_test_');
    dbPath = '${tempDir.path}/test_prices.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
    dbService = DatabaseService.instance;

    connectivityService = ConnectivityService();
    mockApiService = MockApiService()..delay = Duration.zero;

    priceRepository = PriceRepository(
      dbService: dbService,
      apiService: mockApiService,
      connectivityService: connectivityService,
    );

    audioService = AudioService()..isTestMode = true;
  });

  tearDown(() async {
    audioService.dispose();
    connectivityService.dispose();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Price Board Data Flow & Caching Tests', () {
    test('1. Online State: Retrieves prices from API and caches them into SQLite', () async {
      // Step 1: Set Online
      connectivityService.setMockIsConnected(true);

      // Verify SQLite is initially empty
      final initialSqlitePrices = await dbService.getPrices();
      expect(initialSqlitePrices, isEmpty);

      // Step 2: Fetch prices via repository
      final result = await priceRepository.fetchPrices();

      // Step 3: Verify returned data is marked online and matches API
      expect(result.isOffline, isFalse);
      expect(result.prices.length, greaterThanOrEqualTo(5));

      final pcbPrice = result.prices.firstWhere((p) => p.id == 'pcb_motherboard');
      expect(pcbPrice.material, equals('PCB'));
      expect(pcbPrice.minPrice, equals(240.0));
      expect(pcbPrice.maxPrice, equals(290.0));
      expect(pcbPrice.unit, equals('kg'));
      expect(pcbPrice.location, equals('Nagpur'));

      // Step 4: Verify prices are now persistently cached in SQLite
      final cachedPrices = await dbService.getPrices();
      expect(cachedPrices.length, equals(result.prices.length));
      expect(cachedPrices.any((p) => p.id == 'pcb_motherboard'), isTrue);
    });

    test('2. Offline State: Serves cached prices from SQLite with offline flag', () async {
      // First populate SQLite cache while online
      connectivityService.setMockIsConnected(true);
      await priceRepository.fetchPrices();

      // Now switch to Offline
      connectivityService.setMockIsConnected(false);
      expect(await connectivityService.isConnected(), isFalse);

      // Fetch prices while offline
      final offlineResult = await priceRepository.fetchPrices();

      // Verify marked as offline and prices loaded from SQLite
      expect(offlineResult.isOffline, isTrue);
      expect(offlineResult.prices, isNotEmpty);
      expect(offlineResult.prices.firstWhere((p) => p.id == 'pcb_motherboard').minPrice, equals(240.0));
      expect(offlineResult.prices.firstWhere((p) => p.id == 'pcb_motherboard').maxPrice, equals(290.0));
    });

    test('3. First-run Offline Fallback: Populates and returns default baseline prices when DB is empty', () async {
      connectivityService.setMockIsConnected(false);

      final emptyResult = await priceRepository.fetchPrices();
      expect(emptyResult.isOffline, isTrue);
      expect(emptyResult.prices, isNotEmpty);

      // Verify SQLite was seeded
      final seeded = await dbService.getPrices();
      expect(seeded, isNotEmpty);
    });
  });

  group('Audio Service & TTS Price Range Speech Tests', () {
    test('English TTS format: "PCB. Two hundred forty to two hundred ninety rupees per kilogram."', () {
      final speechText = audioService.generatePriceSpeechText(
        material: 'PCB',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        languageCode: 'en',
      );

      expect(
        speechText,
        equals('PCB. Two hundred forty to two hundred ninety rupees per kilogram.'),
      );
    });

    test('Hindi TTS format: "पीसीबी. दो सौ चालीस से दो सौ नब्बे रुपये प्रति किलोग्राम।', () {
      final speechText = audioService.generatePriceSpeechText(
        material: 'पीसीबी',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        languageCode: 'hi',
      );

      expect(
        speechText,
        equals('पीसीबी. दो सौ चालीस से दो सौ नब्बे रुपये प्रति किलोग्राम।'),
      );
    });

    test('Marathi TTS format: "पीसीबी. दोनशे चाळीस ते दोनशे नव्वद रुपये प्रति किलो."', () {
      final speechText = audioService.generatePriceSpeechText(
        material: 'पीसीबी',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        languageCode: 'mr',
      );

      expect(
        speechText,
        equals('पीसीबी. दोनशे चाळीस ते दोनशे नव्वद रुपये प्रति किलो.'),
      );
    });

    test('AudioService speak and stop functionality', () async {
      await audioService.speakPriceRange(
        material: 'Copper Wire',
        minPrice: 450.0,
        maxPrice: 620.0,
        unit: 'kg',
        languageCode: 'en',
      );

      expect(audioService.lastSpokenText, contains('Copper Wire'));
      expect(audioService.lastSpokenText, contains('Four hundred fifty'));
      expect(audioService.lastSpokenText, contains('six hundred twenty'));

      await audioService.stop();
      expect(audioService.isSpeaking, isFalse);
    });
  });

  group('PriceCard UI Component Tests', () {
    testWidgets('PriceCard displays indicative range, location, last updated, source, and listen button',
        (WidgetTester tester) async {
      final testPrice = Price(
        id: 'pcb_test',
        material: 'PCB',
        categoryNameEn: 'PCB / Motherboard',
        categoryNameHi: 'पीसीबी / मदरबोर्ड',
        categoryNameMr: 'पीसीबी / मदरबोर्ड',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: DateTime.now(),
        iconAsset: 'developer_board',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
          ],
          home: Scaffold(
            body: PriceCard(
              price: testPrice,
              currentLanguage: 'en',
              audioService: audioService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Material Name
      expect(find.text('PCB / Motherboard'), findsOneWidget);

      // Verify Indicative Price Range
      expect(find.text('₹240 – ₹290 / kg'), findsOneWidget);

      // Verify Location
      expect(find.text('Nagpur'), findsOneWidget);

      // Verify Updated today
      expect(find.text('Updated today'), findsOneWidget);

      // Verify Source
      expect(find.textContaining('Formal Recycler Benchmark'), findsOneWidget);

      // Verify Listen Button
      expect(find.textContaining('Listen'), findsOneWidget);

      // Tap Listen Button and verify audio dispatch
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(audioService.lastSpokenText, contains('PCB / Motherboard'));
    });
  });
}
