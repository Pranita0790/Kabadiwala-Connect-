import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/screens/lot/create_lot_screen.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_create_lot_');
    DatabaseService.setTestFactory(
      databaseFactoryFfi,
      customPath: '${tempDir.path}/test.db',
    );
    ConnectivityService.instance.setMockIsConnected(false);
  });

  tearDown(() async {
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } on FileSystemException {
      // Windows may still hold the SQLite file handle briefly.
    }
  });

  testWidgets('shows estimated ₹ range from rate card factors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CreateLotScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Estimated Value'), findsOneWidget);
    expect(find.textContaining('Based on material, condition, and weight'), findsOneWidget);
    expect(find.textContaining('last-known'), findsOneWidget);
  });
}
