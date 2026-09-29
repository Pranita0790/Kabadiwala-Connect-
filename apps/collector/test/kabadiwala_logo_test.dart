import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/core/constants/app_constants.dart';
import 'package:kabadiwala_connect/screens/splash/splash_screen.dart';
import 'package:kabadiwala_connect/widgets/kabadiwala_logo.dart';

void main() {
  group('KabadiwalaLogo & Branding Widget Tests', () {
    testWidgets('KabadiwalaLogo widget builds with correct asset path and BoxFit.contain', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KabadiwalaLogo(
              width: 100,
              height: 100,
              isCircular: true,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );

      final logoFinder = find.byType(KabadiwalaLogo);
      expect(logoFinder, findsOneWidget);

      final clipOvalFinder = find.byType(ClipOval);
      expect(clipOvalFinder, findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));
      expect((imageWidget.image as AssetImage).assetName, equals(AppConstants.logoAsset));
    });

    testWidgets('KabadiwalaLogo renders rounded-square with ClipRRect when isCircular is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KabadiwalaLogo(
              width: 80,
              height: 80,
              isCircular: false,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('SplashScreen renders circular logo and tagline prominently on clean background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(KabadiwalaLogo), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Connecting Collectors • Fair Prices • Formal Recycling'), findsOneWidget);
    });
  });
}
