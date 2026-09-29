import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kabadiwala_connect/core/auth/auth_controller.dart';
import 'package:kabadiwala_connect/core/localization/app_localizations.dart';
import 'package:kabadiwala_connect/core/localization/locale_controller.dart';
import 'package:kabadiwala_connect/models/user_profile.dart';
import 'package:kabadiwala_connect/repositories/lot_repository.dart';
import 'package:kabadiwala_connect/repositories/price_repository.dart';
import 'package:kabadiwala_connect/repositories/transaction_repository.dart';
import 'package:kabadiwala_connect/main.dart';
import 'package:kabadiwala_connect/screens/auth/auth_landing_screen.dart';
import 'package:kabadiwala_connect/screens/auth/login_screen.dart';
import 'package:kabadiwala_connect/screens/auth/sign_up_screen.dart';
import 'package:kabadiwala_connect/screens/auth/onboarding_screen.dart';
import 'package:kabadiwala_connect/screens/auth/otp_verification_screen.dart';
import 'package:kabadiwala_connect/screens/auth/profile_setup_screen.dart';
import 'package:kabadiwala_connect/screens/profile/edit_profile_screen.dart';
import 'package:kabadiwala_connect/screens/profile/profile_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/auth_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/notification_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late DatabaseService dbService;
  late AuthService authService;
  late AuthController authController;
  late LocaleController localeController;
  late SyncService syncService;
  late LotRepository lotRepository;
  late TransactionRepository transactionRepository;
  late PriceRepository priceRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_auth_test_');
    DatabaseService.setTestFactory(
      databaseFactoryFfi,
      customPath: '${tempDir.path}/test_auth.db',
    );
    dbService = DatabaseService.instance;
    await dbService.database;
    authService = AuthService(dbService: dbService);
    authController = AuthController(authService: authService);
    await authController.initialize();
    AuthController.setInstance(authController);
    localeController = LocaleController(dbService: dbService);
    await localeController.initialize();
    ConnectivityService.instance.setMockIsConnected(false);
    NotificationService.setInstance(NotificationService(
      dbService: dbService,
      apiService: MockApiService(),
    ));
    syncService = SyncService(
      dbService: dbService,
      connectivityService: ConnectivityService.instance,
      autoSyncOnOnline: false,
    );
    SyncService.setInstance(syncService);
    lotRepository = LotRepository(dbService: dbService);
    transactionRepository = TransactionRepository(
      dbService: dbService,
      apiService: MockApiService(),
      connectivityService: ConnectivityService.instance,
    );
    priceRepository = PriceRepository(
      dbService: dbService,
      apiService: MockApiService(),
      connectivityService: ConnectivityService.instance,
    );
  });

  tearDown(() async {
    syncService.dispose();
    SyncService.setInstance(null);
    NotificationService.resetForTesting();
    AuthController.resetForTesting();
    ConnectivityService.instance.resetForTesting();
    await DatabaseService.closeDatabase();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createTestWidget(Widget child, {Locale locale = const Locale('en')}) {
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
        '/auth-landing': (context) => const AuthLandingScreen(),
        '/login': (context) => LoginScreen(authController: authController),
        '/signup': (context) => SignUpScreen(authController: authController),
        '/profile-setup': (context) => ProfileSetupScreen(authController: authController),
        '/onboarding': (context) => const OnboardingScreen(),
        '/profile': (context) => ProfileScreen(
              authController: authController,
              localeController: localeController,
            ),
        '/edit-profile': (context) => EditProfileScreen(authController: authController),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/otp') {
          final phone = settings.arguments as String?;
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => OtpVerificationScreen(
              phoneNumber: phone,
              authController: authController,
            ),
          );
        }
        return null;
      },
      home: child,
    );
  }

  group('AuthService & AuthController Unit Tests', () {
    test('Phone number and Password validation rules', () {
      expect(AuthService.validateIndianMobile(null), 'emptyPhone');
      expect(AuthService.validateIndianMobile(''), 'emptyPhone');
      expect(AuthService.validateIndianMobile('12345'), 'invalidPhoneLength');
      expect(AuthService.validateIndianMobile('1234567890'), 'invalidStartDigit');
      expect(AuthService.validateIndianMobile('9876543210'), isNull);
      expect(AuthService.validateIndianMobile('+91 98765 43210'), isNull);

      expect(AuthService.validatePassword(null), 'emptyPassword');
      expect(AuthService.validatePassword('123'), 'passwordLengthError');
      expect(AuthService.validatePassword('123456'), isNull);
    });

    test('Scenario A: Sign Up flow initiates OTP and creates user upon verification', () async {
      final initiated = await authController.initiateSignUp(
        name: 'Ramesh Shinde',
        phone: '9876543210',
        password: 'securePassword123',
        city: 'Pune',
        role: 'collector',
      );
      expect(initiated, isTrue);
      expect(authController.pendingPhoneNumber, '9876543210');

      // Verify with incorrect OTP
      final badResult = await authController.verifyOtp('000000');
      expect(badResult.success, isFalse);

      // Verify with universal demo OTP '123456'
      final goodResult = await authController.verifyOtp('123456');
      expect(goodResult.success, isTrue);
      expect(goodResult.isNewUser, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.name, 'Ramesh Shinde');
      expect(authController.currentUser?.city, 'Pune');

      // Verify user saved locally in SQLite
      final savedUser = await dbService.getUser(authController.currentUser!.id);
      expect(savedUser, isNotNull);
      expect(savedUser!.name, 'Ramesh Shinde');
      expect(savedUser.passwordHash, isNotNull);
    });

    test('Scenario B: Existing user Login with password (NO OTP required)', () async {
      // 1. Create existing user
      final createdUser = await authService.createAccountWithPassword(
        name: 'Suresh Patil',
        phoneNumber: '9876543210',
        password: 'myPassword123',
        city: 'Pune',
        role: 'collector',
      );
      expect(createdUser, isNotNull);

      // 2. Attempt login with bad password
      final badLogin = await authController.login(
        phone: '9876543210',
        password: 'wrongPassword',
      );
      expect(badLogin.success, isFalse);
      expect(authController.isAuthenticated, isFalse);

      // 3. Attempt login with correct password -> directly authenticated
      final goodLogin = await authController.login(
        phone: '9876543210',
        password: 'myPassword123',
      );
      expect(goodLogin.success, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.name, 'Suresh Patil');
    });

    test('Scenario C: Existing user session restored on initialize', () async {
      final user = await authService.createAccountWithPassword(
        name: 'Vijay Kumar',
        phoneNumber: '9876543210',
        password: 'password123',
        city: 'Nagpur',
      );
      await dbService.setCurrentUserId(user.id);

      // Create new fresh controller instance
      final freshController = AuthController(authService: authService);
      await freshController.initialize();

      expect(freshController.isAuthenticated, isTrue);
      expect(freshController.currentUser?.name, 'Vijay Kumar');
    });

    test('Scenario D: Logout clears SQLite session state', () async {
      final user = await authService.createAccountWithPassword(
        name: 'Santosh Kumar',
        phoneNumber: '9876543210',
        password: 'password123',
        city: 'Nagpur',
      );
      authController.setCurrentUser(user);
      expect(authController.isAuthenticated, isTrue);

      await authController.logout();
      expect(authController.currentUser, isNull);
      expect(authController.isAuthenticated, isFalse);

      final currentDbUser = await dbService.getCurrentUser();
      expect(currentDbUser, isNull);
    });

    test('Scenario E: Existing number during Sign Up detected', () async {
      await authService.createAccountWithPassword(
        name: 'Existing Collector',
        phoneNumber: '9876543210',
        password: 'password123',
        city: 'Mumbai',
      );

      final exists = await authService.checkUserExists('9876543210');
      expect(exists, isTrue);

      final nonExistent = await authService.checkUserExists('9123456780');
      expect(nonExistent, isFalse);
    });
  });

  group('AuthLandingScreen Widget Tests', () {
    testWidgets('Renders Namaste, Welcome, LOGIN, and CREATE ACCOUNT choices', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(const AuthLandingScreen()));
      await tester.pump();

      expect(find.text('Namaste 👋'), findsOneWidget);
      expect(find.text('Welcome to Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Sell, track and manage your scrap easily.'), findsOneWidget);
      expect(find.byKey(const Key('landing_login_btn')), findsOneWidget);
      expect(find.byKey(const Key('landing_signup_btn')), findsOneWidget);
    });

    testWidgets('Tapping LOGIN opens LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(const AuthLandingScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('landing_login_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('Login to continue to Kabadiwala Connect'), findsOneWidget);
      expect(find.byKey(const Key('login_submit_btn')), findsOneWidget);
    });

    testWidgets('Tapping CREATE ACCOUNT opens SignUpScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(const AuthLandingScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('landing_signup_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Create your account 👋'), findsOneWidget);
      expect(find.text('Join Kabadiwala Connect'), findsOneWidget);
      expect(find.byKey(const Key('signup_submit_btn')), findsOneWidget);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders Mobile, Password, Show/Hide toggle, and no OTP', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(LoginScreen(authController: authController)));
      await tester.pump();

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_toggle_password_btn')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_btn')), findsOneWidget);
      expect(find.text('Get OTP'), findsNothing); // NO OTP ON LOGIN SCREEN
    });

    testWidgets('Shows error on invalid mobile or empty password', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(LoginScreen(authController: authController)));
      await tester.pump();

      // Enter invalid phone
      await tester.enterText(find.byKey(const Key('login_phone_field')), '1234');
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pump();

      expect(find.text('Please enter a valid 10-digit mobile number'), findsOneWidget);

      // Enter valid phone but empty password
      await tester.enterText(find.byKey(const Key('login_phone_field')), '9876543210');
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pump();

      expect(find.text('Enter password'), findsNWidgets(2));
    });
  });

  group('SignUpScreen Widget Tests', () {
    testWidgets('Renders all registration fields, city chips, and role cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(SignUpScreen(authController: authController)));
      await tester.pump();

      expect(find.text('Create your account 👋'), findsOneWidget);
      expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_password_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_city_field')), findsOneWidget);
      expect(find.text('Scrap Collector'), findsOneWidget);
      expect(find.text('Recycler'), findsOneWidget);
      expect(find.byKey(const Key('signup_submit_btn')), findsOneWidget);
    });

    testWidgets('Validates password match and length on Sign Up', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(SignUpScreen(authController: authController)));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('signup_name_field')), 'Ramesh Shinde');
      await tester.enterText(find.byKey(const Key('signup_phone_field')), '9876543210');
      await tester.enterText(find.byKey(const Key('signup_password_field')), '123'); // short
      await tester.enterText(find.byKey(const Key('signup_confirm_password_field')), '123');
      await tester.enterText(find.byKey(const Key('signup_city_field')), 'Pune');

      await tester.tap(find.byKey(const Key('signup_submit_btn')));
      await tester.pump();

      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      // Mismatched passwords
      await tester.enterText(find.byKey(const Key('signup_password_field')), 'password123');
      await tester.enterText(find.byKey(const Key('signup_confirm_password_field')), 'differentPass');
      await tester.tap(find.byKey(const Key('signup_submit_btn')));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('KabadiwalaConnectApp Root Auth Gate Tests', () {
    testWidgets('Fresh install / unauthenticated user lands directly on AuthLandingScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      expect(authController.isAuthenticated, isFalse);

      await tester.pumpWidget(KabadiwalaConnectApp(
        authController: authController,
        localeController: localeController,
        syncService: syncService,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should be on Auth Landing screen with Namaste & Welcome choices
      expect(find.text('Namaste 👋'), findsOneWidget);
      expect(find.text('Welcome to Kabadiwala Connect'), findsOneWidget);
      expect(find.byKey(const Key('landing_login_btn')), findsOneWidget);
      expect(find.byKey(const Key('landing_signup_btn')), findsOneWidget);
    });

    testWidgets('Authenticated existing user lands directly on HomeScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final user = UserProfile.create(
        id: 'user_auth_gate_1',
        name: 'Suresh Patil',
        phoneNumber: '+919876543210',
        city: 'Pune',
        role: 'collector',
      );
      await tester.runAsync(() async {
        await dbService.saveUser(user);
        await dbService.setCurrentUserId(user.id);
      });
      authController.setCurrentUser(user);
      expect(authController.isAuthenticated, isTrue);

      await tester.pumpWidget(createTestWidget(
        AuthGate(
          authController: authController,
          localeController: localeController,
          syncService: syncService,
          lotRepository: lotRepository,
          transactionRepository: transactionRepository,
          priceRepository: priceRepository,
          connectivityService: ConnectivityService.instance,
        ),
      ));
      await tester.pump();

      // Should be on Home screen
      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Namaste 👋'), findsNothing);
    });
  });
}
