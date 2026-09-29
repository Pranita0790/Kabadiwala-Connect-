import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/core/localization/locale_controller.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/widgets/language_selector.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_l10n_test_');
    dbPath = '${tempDir.path}/test_kabadiwala_l10n.db';
    DatabaseService.setTestFactory(databaseFactoryFfi, customPath: dbPath);
  });

  tearDown(() async {
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppLocalizations Keys and Natural Translations', () {
    const requiredKeys = [
      'home',
      'createLot',
      'camera',
      'material',
      'weight',
      'condition',
      'save',
      'retake',
      'priceBoard',
      'listen',
      'earnings',
      'totalEarnings',
      'paid',
      'pending',
      'offline',
      'synced',
      'syncing',
      'failed',
      'retry',
      'lastUpdated',
      'noInternet',
      'noTransactions',
    ];

    test('English translations exist and are non-empty for all required keys', () {
      final locEn = AppLocalizations(const Locale('en'));
      for (final key in requiredKeys) {
        final val = locEn.translate(key);
        expect(val, isNotEmpty, reason: 'Key $key should have a translation in English');
        expect(val, isNot(equals(key)), reason: 'Key $key should not return the fallback raw key in English');
      }
    });

    test('Hindi translations exist and are culturally natural for informal collectors', () {
      final locHi = AppLocalizations(const Locale('hi'));
      for (final key in requiredKeys) {
        final val = locHi.translate(key);
        expect(val, isNotEmpty, reason: 'Key $key should have a translation in Hindi');
        expect(val, isNot(equals(key)), reason: 'Key $key should not return raw key in Hindi');
      }

      // Check specific natural colloquial collector terms
      expect(locHi.translate('home'), equals('होम'));
      expect(locHi.translate('createLot'), equals('नया माल जोड़ें'));
      expect(locHi.translate('priceBoard'), equals('भाव बोर्ड'));
      expect(locHi.translate('listen'), equals('सुनें'));
      expect(locHi.translate('paid'), equals('भुगतान प्राप्त'));
      expect(locHi.translate('pending'), equals('बाकी'));
      expect(locHi.translate('offline'), equals('ऑफ़लाइन'));
    });

    test('Marathi translations exist and are culturally natural for informal collectors', () {
      final locMr = AppLocalizations(const Locale('mr'));
      for (final key in requiredKeys) {
        final val = locMr.translate(key);
        expect(val, isNotEmpty, reason: 'Key $key should have a translation in Marathi');
        expect(val, isNot(equals(key)), reason: 'Key $key should not return raw key in Marathi');
      }

      // Check specific natural colloquial collector terms
      expect(locMr.translate('home'), equals('होम'));
      expect(locMr.translate('createLot'), equals('नवीन माल नोंदवा'));
      expect(locMr.translate('priceBoard'), equals('दर फलक'));
      expect(locMr.translate('listen'), equals('ऐका'));
      expect(locMr.translate('paid'), equals('भरणा झाला'));
      expect(locMr.translate('pending'), equals('प्रलंबित'));
      expect(locMr.translate('offline'), equals('ऑफलाइन'));
    });
  });

  group('LocaleController Local Persistence and Reactivity', () {
    test('Defaults to English and persists language preference to SQLite', () async {
      final controller = LocaleController(dbService: DatabaseService.instance);
      await controller.initialize();

      expect(controller.currentLanguageCode, equals('en'));
      expect(controller.currentLocale, equals(const Locale('en')));

      // Change to Hindi
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.setLanguageCode('hi');

      expect(notified, isTrue);
      expect(controller.currentLanguageCode, equals('hi'));
      expect(controller.currentLocale, equals(const Locale('hi')));

      // Verify persistence by initializing a fresh instance
      final controller2 = LocaleController(dbService: DatabaseService.instance);
      await controller2.initialize();
      expect(controller2.currentLanguageCode, equals('hi'));
      expect(controller2.currentLocale, equals(const Locale('hi')));
    });

    test('Changes to Marathi and persists successfully', () async {
      final controller = LocaleController(dbService: DatabaseService.instance);
      await controller.initialize();

      await controller.setLanguageCode('mr');
      expect(controller.currentLanguageCode, equals('mr'));
      expect(controller.currentLocale, equals(const Locale('mr')));

      final saved = await DatabaseService.instance.getLanguagePreference();
      expect(saved, equals('mr'));
    });
  });

  group('Dynamic UI Language Switching Without Restart', () {
    testWidgets('Switching language immediately updates widget tree without restart', (tester) async {
      final controller = LocaleController(dbService: DatabaseService.instance);
      await tester.runAsync(() => controller.initialize());

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final locale = controller.currentLocale;
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
              home: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Scaffold(
                    body: Column(
                      children: [
                        Text(loc.translate('appTitle')),
                        Text(loc.translate('createLot')),
                        Text(loc.translate('priceBoard')),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // In English initially
      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Create Lot'), findsOneWidget);
      expect(find.text('Price Board'), findsOneWidget);

      // Dynamically switch to Hindi
      await tester.runAsync(() => controller.setLanguageCode('hi'));
      await tester.pumpAndSettle();

      // Verify immediate update to Hindi
      expect(find.text('कबाड़ीवाला कनेक्ट'), findsOneWidget);
      expect(find.text('नया माल जोड़ें'), findsOneWidget);
      expect(find.text('भाव बोर्ड'), findsOneWidget);

      // Dynamically switch to Marathi
      await tester.runAsync(() => controller.setLanguageCode('mr'));
      await tester.pumpAndSettle();

      // Verify immediate update to Marathi
      expect(find.text('कबाडीवाला कनेक्ट'), findsOneWidget);
      expect(find.text('नवीन माल नोंदवा'), findsOneWidget);
      expect(find.text('दर फलक'), findsOneWidget);
    });

    testWidgets('LanguageSelectorMenu popup renders supported languages and selects them', (tester) async {
      final controller = LocaleController(dbService: DatabaseService.instance);
      await tester.runAsync(() => controller.initialize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                LanguageSelectorMenu(controller: controller),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap language selector icon
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Check popup menu items
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('मराठी'), findsOneWidget);

      // Select Marathi
      await tester.tap(find.text('मराठी'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      expect(controller.currentLanguageCode, equals('mr'));
    });

    testWidgets('LanguageSelector checkmark dynamically moves: English -> Hindi -> Marathi -> English', (tester) async {
      final controller = LocaleController(
        dbService: DatabaseService.instance,
        initialLocale: const Locale('en'),
      );
      await tester.runAsync(() => controller.initialize());

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return MaterialApp(
              locale: controller.currentLocale,
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
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    LanguageSelectorMenu(controller: controller),
                  ],
                ),
                body: const Center(child: Text('Home')),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial state: English
      // Open dropdown
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Verify all 3 options exist
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('मराठी'), findsOneWidget);

      // Exactly ONE checkmark visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Verify the checkmark is in the English popup item row
      final englishItemFinder = find.ancestor(
        of: find.text('English'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: englishItemFinder, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );

      final hindiItemFinder = find.ancestor(
        of: find.text('हिंदी'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: hindiItemFinder, matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );

      final marathiItemFinder = find.ancestor(
        of: find.text('मराठी'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: marathiItemFinder, matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );

      // 2. Select Hindi (English -> Hindi)
      await tester.tap(find.text('हिंदी'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      expect(controller.currentLanguageCode, equals('hi'));

      // Reopen dropdown
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Exactly ONE checkmark visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Checkmark must be next to Hindi only
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('हिंदी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('English'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('मराठी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );

      // 3. Select Marathi (Hindi -> Marathi)
      await tester.tap(find.text('मराठी'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      expect(controller.currentLanguageCode, equals('mr'));

      // Reopen dropdown
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Exactly ONE checkmark visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Checkmark must be next to Marathi only
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('मराठी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('English'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('हिंदी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );

      // 4. Select English (Marathi -> English)
      await tester.tap(find.text('English'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      expect(controller.currentLanguageCode, equals('en'));

      // Reopen dropdown
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      // Exactly ONE checkmark visible next to English
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('English'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('हिंदी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('मराठी'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );

      // Close menu
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
    });
  });
}
