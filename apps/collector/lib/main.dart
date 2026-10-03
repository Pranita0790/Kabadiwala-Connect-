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
import 'screens/camera/camera_screen.dart';
import 'screens/earnings/earnings_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lot/create_lot_screen.dart';
import 'screens/prices/prices_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/lot/lot_details_screen.dart';
import 'screens/recycler/recycler_handover_screen.dart';
import 'screens/recycler/recycler_matching_screen.dart';
import 'screens/handover/handover_qr_screen.dart';
import 'screens/safety/safety_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'models/e_waste_lot.dart';
import 'models/recycler.dart';

import 'repositories/lot_repository.dart';
import 'repositories/price_repository.dart';
import 'repositories/transaction_repository.dart';
import 'services/connectivity_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize persisted language preference from SQLite
  final localeController = LocaleController.instance;
  await localeController.initialize();

  // Initialize auth session state from SQLite
  final authController = AuthController.instance;
  await authController.initialize();

  // Startup Database Verification
  try {
    final db = await DatabaseService.instance.database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tables.map((t) => t['name'] as String).toList();
    debugPrint('=== [DB STARTUP CHECK] ===');
    debugPrint('DB Path: ${db.path}');
    debugPrint('DB Version: ${await db.getVersion()}');
    debugPrint('DB Tables: $tableNames');
    debugPrint('Notifications table exists: ${tableNames.contains("notifications")}');
    debugPrint('Users table exists: ${tableNames.contains("users")}');
    debugPrint('===========================');
  } catch (e) {
    debugPrint('=== [DB STARTUP ERROR] === $e');
  }

  runApp(KabadiwalaConnectApp(
    localeController: localeController,
    authController: authController,
  ));
}

class KabadiwalaConnectApp extends StatelessWidget {
  final LocaleController? localeController;
  final AuthController? authController;
  final LotRepository? lotRepository;
  final TransactionRepository? transactionRepository;
  final PriceRepository? priceRepository;
  final SyncService? syncService;
  final ConnectivityService? connectivityService;
  final NotificationService? notificationService;

  const KabadiwalaConnectApp({
    super.key,
    this.localeController,
    this.authController,
    this.lotRepository,
    this.transactionRepository,
    this.priceRepository,
    this.syncService,
    this.connectivityService,
    this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final controller = localeController ?? LocaleController.instance;
    final auth = authController ?? AuthController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentLocale = controller.currentLocale;

        Widget buildAuthGate() {
          return AuthGate(
            localeController: controller,
            authController: auth,
            lotRepository: lotRepository,
            transactionRepository: transactionRepository,
            priceRepository: priceRepository,
            syncService: syncService,
            connectivityService: connectivityService,
            notificationService: notificationService,
          );
        }

        return MaterialApp(
          title: 'Kabadiwala Connect',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          locale: currentLocale,
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
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => buildAuthGate(),
                );
              case '/home':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => HomeScreen(
                    onLanguageChanged: controller.setLocale,
                    currentLocale: currentLocale,
                    lotRepository: lotRepository,
                    transactionRepository: transactionRepository,
                    syncService: syncService,
                    connectivityService: connectivityService,
                    notificationService: notificationService,
                    authController: auth,
                  ),
                );
              case '/auth-landing':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const AuthLandingScreen(),
                );
              case '/login':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => LoginScreen(
                    authController: auth,
                    onLanguageChanged: controller.setLocale,
                  ),
                );
              case '/signup':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => SignUpScreen(
                    authController: auth,
                    onLanguageChanged: controller.setLocale,
                  ),
                );
              case '/otp':
                final phoneArg = settings.arguments as String?;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => OtpVerificationScreen(
                    phoneNumber: phoneArg,
                    authController: auth,
                  ),
                );
              case '/profile-setup':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => ProfileSetupScreen(
                    authController: auth,
                  ),
                );
              case '/onboarding':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const OnboardingScreen(),
                );
              case '/profile':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => ProfileScreen(
                    authController: auth,
                    localeController: controller,
                    lotRepository: lotRepository,
                    transactionRepository: transactionRepository,
                    onLanguageChanged: controller.setLocale,
                  ),
                );
              case '/edit-profile':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => EditProfileScreen(
                    authController: auth,
                  ),
                );
              case '/splash':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => SplashScreen(
                    onInitializationComplete: () {
                      if (auth.isAuthenticated) {
                        Navigator.pushReplacementNamed(context, '/');
                      } else {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                  ),
                );
              case '/camera':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const CameraScreen(),
                );
              case '/create-lot':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => CreateLotScreen(
                    lotRepository: lotRepository,
                  ),
                );
              case '/lot-details':
                final lot = settings.arguments as EWasteLot;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => LotDetailsScreen(lot: lot),
                );
              case '/recycler-handover':
                final args = settings.arguments;
                EWasteLot? lot;
                Recycler? recycler;
                if (args is EWasteLot) {
                  lot = args;
                } else if (args is Map<String, dynamic>) {
                  lot = args['lot'] as EWasteLot?;
                  recycler = args['recycler'] as Recycler?;
                } else if (args is Recycler) {
                  recycler = args;
                }
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => HandoverQrScreen(
                    lot: lot,
                    recycler: recycler,
                    lotRepository: lotRepository,
                    transactionRepository: transactionRepository,
                  ),
                );
              case '/handover-payment':
                final lot = settings.arguments as EWasteLot;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => RecyclerHandoverScreen(
                    lot: lot,
                    lotRepository: lotRepository,
                    transactionRepository: transactionRepository,
                  ),
                );
              case '/recyclers':
                final lot = settings.arguments as EWasteLot?;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => RecyclerMatchingScreen(
                    lot: lot,
                    lotRepository: lotRepository,
                  ),
                );
              case '/safety':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const SafetyScreen(),
                );
              case '/notifications':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const NotificationsScreen(),
                );
              case '/prices':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => PricesScreen(
                    currentLocale: currentLocale,
                    priceRepository: priceRepository,
                    connectivityService: connectivityService,
                  ),
                );
              case '/earnings':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => EarningsScreen(repository: transactionRepository),
                );
              default:
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => HomeScreen(
                    onLanguageChanged: controller.setLocale,
                    currentLocale: currentLocale,
                    lotRepository: lotRepository,
                    transactionRepository: transactionRepository,
                    syncService: syncService,
                    connectivityService: connectivityService,
                    authController: auth,
                  ),
                );
            }
          },
        );
      },
    );
  }
}

/// Dynamic Authentication Gate widget.
/// Renders HomeScreen if user has an active authenticated session,
/// otherwise renders LoginScreen (Namaste greeting).
class AuthGate extends StatelessWidget {
  final LocaleController? localeController;
  final AuthController? authController;
  final LotRepository? lotRepository;
  final TransactionRepository? transactionRepository;
  final PriceRepository? priceRepository;
  final SyncService? syncService;
  final ConnectivityService? connectivityService;
  final NotificationService? notificationService;

  const AuthGate({
    super.key,
    this.localeController,
    this.authController,
    this.lotRepository,
    this.transactionRepository,
    this.priceRepository,
    this.syncService,
    this.connectivityService,
    this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final auth = authController ?? AuthController.instance;
    final controller = localeController ?? LocaleController.instance;

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isAuthenticated) {
          return HomeScreen(
            onLanguageChanged: controller.setLocale,
            currentLocale: controller.currentLocale,
            lotRepository: lotRepository,
            transactionRepository: transactionRepository,
            syncService: syncService,
            connectivityService: connectivityService,
            notificationService: notificationService,
            authController: auth,
          );
        }
        return const AuthLandingScreen();
      },
    );
  }
}
