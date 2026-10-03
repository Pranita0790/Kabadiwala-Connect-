import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_test/flutter_test.dart";
import "package:kabadiwala_connect/core/localization/app_localizations.dart";
import "package:kabadiwala_connect/models/recycler.dart";
import "package:kabadiwala_connect/screens/recycler/recycler_matching_screen.dart";

void main() {
  testWidgets("ORG recycler from backend is visible in list", (tester) async {
    final org = Recycler(
      id: "fc6ba8ec-f3dc-4938-a26a-91734a2ead0d",
      name: "ORG",
      address: "ShivSai SRA CHS LTD Buliding, Sindhi Society, Chembur, Mumbai, Maharashtra 400071",
      acceptedCategories: const [],
      distanceKm: 0,
      isAuthorized: false,
      rating: 4.5,
      contactPhone: null,
      latitude: 0,
      longitude: 0,
      indicativePrice: null,
      unit: "kg",
      isDemo: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale("en")],
        home: RecyclerMatchingScreen(initialRecyclers: [org]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("ORG"), findsOneWidget);
    expect(find.textContaining("1"), findsWidgets);
  });
}
