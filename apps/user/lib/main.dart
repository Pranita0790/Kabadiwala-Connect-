import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/auth/auth_controller.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/auth_landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'services/sync_service.dart';
import 'screens/kabadiwala/find_kabadiwala_screen.dart';
import 'screens/kabadiwala/nearby_vendors_screen.dart';
import 'screens/kabadiwala/vendor_details_screen.dart';
import 'screens/kabadiwala/my_kabadiwala_screen.dart';
import 'screens/materials/select_material_screen.dart';
import 'screens/sell_request/sell_request_screen.dart';
import 'screens/sell_request/sell_request_summary_screen.dart';
import 'screens/pickup/pickup_screen.dart';
import 'screens/collection/collection_screen.dart';
import 'screens/payment/payment_screen.dart';
import 'screens/payment/payment_history_screen.dart';
import 'screens/history/collection_history_screen.dart';
import 'screens/reminders/reminders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final localeController = LocaleController.instance;
  await localeController.initialize();

  final authController = AuthController.instance;
  await authController.initialize();

  // Start the offline-first sync pipeline: locally created lots with
  // PENDING_SYNC are uploaded to the backend whenever connectivity returns.
  SyncService.getInstance();

  runApp(KabadiwalaConnectUserApp(
    localeController: localeController,
    authController: authController,
  ));
}

class KabadiwalaConnectUserApp extends StatelessWidget {
  final LocaleController? localeController;
  final AuthController? authController;

  const KabadiwalaConnectUserApp({
    super.key,
    this.localeController,
    this.authController,
  });

  @override
  Widget build(BuildContext context) {
    final controller = localeController ?? LocaleController.instance;
    final auth = authController ?? AuthController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return MaterialApp(
          title: 'Kabadiwala Connect - User',
          theme: AppTheme.themeData,
          debugShowCheckedModeBanner: false,
          locale: controller.currentLocale,
          supportedLocales: controller.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Open the user dashboard directly for the current demo flow.
          initialRoute: '/home',
          routes: {
            '/splash': (context) => SplashScreen(
                  onInitializationComplete: () {
                    if (auth.isAuthenticated) {
                      Navigator.of(context).pushReplacementNamed('/home');
                    } else {
                      Navigator.of(context).pushReplacementNamed('/auth/landing');
                    }
                  },
                ),
            '/auth/landing': (context) => const AuthLandingScreen(),
            '/auth/login': (context) => const LoginScreen(),
            '/auth/sign-up': (context) => const SignUpScreen(),
            '/auth/onboarding': (context) => const OnboardingScreen(),
            '/auth/otp-verification': (context) => const OtpVerificationScreen(),
            '/auth/profile-setup': (context) => const ProfileSetupScreen(),
            '/home': (context) => HomeScreen(
                  onLanguageChanged: controller.setLocale,
                  currentLocale: controller.currentLocale,
                ),
            '/profile': (context) => ProfileScreen(
                  onLanguageChanged: controller.setLocale,
                ),
            '/profile/edit': (context) => const EditProfileScreen(),
            '/kabadiwala/find': (context) => const FindKabadiwalaScreen(),
            '/kabadiwala/nearby': (context) => const NearbyVendorsScreen(),
            '/kabadiwala/vendor/:id': (context) => const VendorDetailsScreen(),
            '/kabadiwala/my': (context) => const MyKabadiwalaScreen(),
            '/materials/select': (context) => const SelectMaterialScreen(),
            '/sell-request': (context) => const SellRequestScreen(),
            '/sell-request/summary': (context) => const SellRequestSummaryScreen(),
            '/pickup': (context) => const PickupScreen(),
            '/collection': (context) => const CollectionScreen(),
            '/payment': (context) => const PaymentScreen(),
            '/payment/history': (context) => const PaymentHistoryScreen(),
            '/history/collection': (context) => const CollectionHistoryScreen(),
            '/reminders': (context) => const RemindersScreen(),
          },
        );
      },
    );
  }
}
