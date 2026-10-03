import 'dart:async';
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
import 'package:kabadiwala_connect/screens/auth/onboarding_screen.dart';
import 'package:kabadiwala_connect/screens/auth/otp_verification_screen.dart';
import 'package:kabadiwala_connect/screens/auth/profile_setup_screen.dart';
import 'package:kabadiwala_connect/screens/auth/sign_up_screen.dart';
import 'package:kabadiwala_connect/screens/profile/edit_profile_screen.dart';
import 'package:kabadiwala_connect/screens/profile/profile_screen.dart';
import 'package:kabadiwala_connect/services/api_service.dart';
import 'package:kabadiwala_connect/services/auth_service.dart';
import 'package:kabadiwala_connect/services/collector_auth_service.dart';
import 'package:kabadiwala_connect/services/connectivity_service.dart';
import 'package:kabadiwala_connect/services/database_service.dart';
import 'package:kabadiwala_connect/services/firebase_auth_service.dart';
import 'package:kabadiwala_connect/services/notification_service.dart';
import 'package:kabadiwala_connect/services/sync_service.dart';

/// A Firebase stand-in: no network, no SDK, deterministic.
///
/// The real FirebaseAuthService delegates to the Firebase SDK, which cannot
/// run in a unit test. Overriding the three methods the controller calls keeps
/// the flow (request -> verify -> exchange) under test without the SDK.
class _FakeFirebaseAuth extends FirebaseAuthService {
  _FakeFirebaseAuth({this.failSend = false, this.failVerify = false});

  final bool failSend;
  final bool failVerify;

  int sendCount = 0;
  int verifyCount = 0;
  bool signedOut = false;

  @override
  Future<String> requestCode(String phone, {Completer<void>? completer}) async {
    sendCount++;
    if (failSend) {
      throw const PhoneAuthException(PhoneAuthFailure.sendFailed);
    }
    return 'verification-id';
  }

  @override
  Future<PhoneAuthIdentity> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    verifyCount++;
    if (failVerify) {
      throw const PhoneAuthException(PhoneAuthFailure.invalidCode);
    }
    return const PhoneAuthIdentity(idToken: 'id-token', firebaseUid: 'firebase-uid');
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

/// A backend stand-in for the token exchange.
class _FakeCollectorAuth extends CollectorAuthService {
  _FakeCollectorAuth(this._store)
      : super(apiBaseUrl: 'http://test.invalid/api', sessionStore: _store);

  final SessionStore _store;
  bool created = true;
  String lastToken = '';

  @override
  Future<SessionExchangeResult> exchangeFirebaseToken({
    required String firebaseIdToken,
    String? fullName,
  }) async {
    lastToken = firebaseIdToken;

    final session = CollectorSession(
      userId: 'backend-user-1',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      role: 'COLLECTOR',
      needsProfile: created,
    );

    await _store.write(session);

    return SessionExchangeResult(session: session, created: created);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late DatabaseService dbService;
  late AuthService authService;
  late SessionStore sessionStore;
  late _FakeFirebaseAuth fakeFirebase;
  late _FakeCollectorAuth fakeCollectorAuth;
  late AuthController authController;
  late LocaleController localeController;
  late SyncService syncService;
  late LotRepository lotRepository;
  late TransactionRepository transactionRepository;
  late PriceRepository priceRepository;

  AuthController buildController() => AuthController(
        authService: authService,
        firebaseAuth: fakeFirebase,
        sessionStore: sessionStore,
        collectorAuth: fakeCollectorAuth,
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sih26_auth_test_');
    DatabaseService.setTestFactory(
      databaseFactoryFfi,
      customPath: '${tempDir.path}/test_auth.db',
    );
    dbService = DatabaseService.instance;
    await dbService.database;
    authService = AuthService(dbService: dbService);
    sessionStore = SessionStore(db: dbService);
    fakeFirebase = _FakeFirebaseAuth();
    fakeCollectorAuth = _FakeCollectorAuth(sessionStore);
    authController = buildController();
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
        '/profile-setup': (context) =>
            ProfileSetupScreen(authController: authController),
        '/onboarding': (context) => const OnboardingScreen(),
        '/profile': (context) => ProfileScreen(
              authController: authController,
              localeController: localeController,
            ),
        '/edit-profile': (context) =>
            EditProfileScreen(authController: authController),
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

  group('Phone rules', () {
    test('validateIndianMobile accepts Indian mobiles and rejects the rest', () {
      expect(AuthService.validateIndianMobile(null), 'emptyPhone');
      expect(AuthService.validateIndianMobile(''), 'emptyPhone');
      expect(AuthService.validateIndianMobile('12345'), 'invalidPhoneLength');
      expect(
        AuthService.validateIndianMobile('1234567890'),
        'invalidStartDigit',
      );
      expect(AuthService.validateIndianMobile('9876543210'), isNull);
      expect(AuthService.validateIndianMobile('+91 98765 43210'), isNull);
    });

    test('normaliseIndianPhone is the E.164 form the backend keys on', () {
      expect(normaliseIndianPhone('9876543210'), '+919876543210');
      expect(normaliseIndianPhone('+91 98765 43210'), '+919876543210');
      expect(normaliseIndianPhone('+919876543210'), '+919876543210');
      expect(normaliseIndianPhone('09876543210'), '+919876543210');

      // Not Indian mobiles.
      expect(normaliseIndianPhone('4155552671'), isNull);
      expect(normaliseIndianPhone('+14155552671'), isNull);
      expect(normaliseIndianPhone('12345'), isNull);
      expect(normaliseIndianPhone(''), isNull);
    });
  });

  group('Phone sign-in flow', () {
    test('sign-up sends a code, verifies it, and stores the profile', () async {
      await authController.initiateSignUp(
        name: 'Ramesh Shinde',
        phoneNumber: '9876543210',
        city: 'Pune',
        role: 'collector',
      );

      expect(fakeFirebase.sendCount, 1);
      expect(authController.pendingPhoneNumber, '9876543210');
      expect(authController.errorMessage, isNull);

      final result = await authController.verifyOtp('123456');

      expect(result.success, isTrue);
      expect(result.isNewUser, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.name, 'Ramesh Shinde');
      expect(authController.currentUser?.city, 'Pune');
      expect(authController.currentUser?.backendUserId, 'backend-user-1');

      // The Firebase ID token is what the backend received, and the local
      // Firebase session is dropped afterwards.
      expect(fakeCollectorAuth.lastToken, 'id-token');
      expect(fakeFirebase.signedOut, isTrue);
    });

    test('a wrong code fails and surfaces the reason', () async {
      fakeFirebase = _FakeFirebaseAuth(failVerify: true);
      fakeCollectorAuth = _FakeCollectorAuth(sessionStore);
      authController = buildController();

      await authController.initiateSignUp(
        name: 'Ramesh',
        phoneNumber: '9876543210',
        city: 'Pune',
      );

      final result = await authController.verifyOtp('000000');

      expect(result.success, isFalse);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.errorMessage, 'authErrorInvalidCode');
    });

    test('a failed send reports a send error, not a success', () async {
      fakeFirebase = _FakeFirebaseAuth(failSend: true);
      fakeCollectorAuth = _FakeCollectorAuth(sessionStore);
      authController = buildController();

      final sent = await authController.sendOtp('9876543210');

      expect(sent, isFalse);
      expect(authController.errorMessage, 'authErrorSendFailed');
    });

    test('a number that is not an Indian mobile is rejected before Firebase',
        () async {
      final sent = await authController.sendOtp('12345');

      expect(sent, isFalse);
      expect(fakeFirebase.sendCount, 0);
      expect(authController.errorMessage, 'invalidPhoneLength');
    });

    test('verify without a pending code reports an expired session', () async {
      final result = await authController.verifyOtp('123456');

      expect(result.success, isFalse);
      expect(authController.errorMessage, 'authErrorSessionExpired');
    });
  });

  group('Offline session', () {
    test('a stored session restores without the network', () async {
      final user = await authService.completeUserProfile(
        phoneNumber: '9876543210',
        name: 'Vijay Kumar',
        city: 'Nagpur',
        backendUserId: 'backend-user-1',
      );
      await dbService.setCurrentUserId(user.id);

      // Fresh controller, as on a cold start with no signal.
      final fresh = buildController();
      await fresh.initialize();

      expect(fresh.isAuthenticated, isTrue);
      expect(fresh.currentUser?.name, 'Vijay Kumar');
    });

    test('logout clears the local session and profile cache', () async {
      final user = await authService.completeUserProfile(
        phoneNumber: '9876543210',
        name: 'Santosh Kumar',
        city: 'Nagpur',
        backendUserId: 'backend-user-1',
      );
      authController.setCurrentUser(user);
      await sessionStore.write(
        const CollectorSession(
          userId: 'backend-user-1',
          accessToken: 'a',
          refreshToken: 'r',
          role: 'COLLECTOR',
        ),
      );

      expect(authController.isAuthenticated, isTrue);

      await authController.logout();

      expect(authController.currentUser, isNull);
      expect(authController.isAuthenticated, isFalse);
      expect(await dbService.getCurrentUser(), isNull);
      expect(await sessionStore.hasSession(), isFalse);
    });
  });

  group('AuthLandingScreen Widget Tests', () {
    testWidgets('Renders welcome copy and both choices', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(const AuthLandingScreen()));
      await tester.pump();

      expect(find.text('Namaste 👋'), findsOneWidget);
      expect(find.text('Welcome to Kabadiwala Connect'), findsOneWidget);
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
      expect(find.byKey(const Key('login_send_code_btn')), findsOneWidget);
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
      expect(find.byKey(const Key('signup_submit_btn')), findsOneWidget);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('Shows phone only, with no password field', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(LoginScreen(authController: authController)),
      );
      await tester.pump();

      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('login_send_code_btn')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsNothing);
      expect(find.text('Password'), findsNothing);
    });

    testWidgets('Rejects an invalid mobile before contacting Firebase',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(LoginScreen(authController: authController)),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('login_phone_field')), '1234');
      await tester.tap(find.byKey(const Key('login_send_code_btn')));
      await tester.pump();

      expect(
        find.text('Please enter a valid 10-digit mobile number'),
        findsOneWidget,
      );
      expect(fakeFirebase.sendCount, 0);
    });
  });

  group('SignUpScreen Widget Tests', () {
    testWidgets('Shows name, mobile, city and role, but no password',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(SignUpScreen(authController: authController)),
      );
      await tester.pump();

      expect(find.text('Create your account 👋'), findsOneWidget);
      expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_city_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_submit_btn')), findsOneWidget);
      expect(find.byKey(const Key('signup_password_field')), findsNothing);
      expect(find.byKey(const Key('signup_confirm_password_field')), findsNothing);
    });

    testWidgets('Requires a name before proceeding', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(SignUpScreen(authController: authController)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('signup_submit_btn')));
      await tester.pump();

      expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
      expect(fakeFirebase.sendCount, 0);
    });
  });

  group('KabadiwalaConnectApp Root Auth Gate Tests', () {
    testWidgets('Unauthenticated user lands on AuthLandingScreen',
        (tester) async {
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

      expect(find.text('Namaste 👋'), findsOneWidget);
      expect(find.byKey(const Key('landing_login_btn')), findsOneWidget);
      expect(find.byKey(const Key('landing_signup_btn')), findsOneWidget);
    });

    testWidgets('Authenticated user lands on HomeScreen', (tester) async {
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

      expect(find.text('Kabadiwala Connect'), findsOneWidget);
      expect(find.text('Namaste 👋'), findsNothing);
    });
  });
}
