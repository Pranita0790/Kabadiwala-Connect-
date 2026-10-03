import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/collector_auth_service.dart';
import '../../services/firebase_auth_service.dart';

/// Central reactive controller for authentication.
///
/// AUTH MODEL
///
/// Collectors sign in with their phone number. Firebase sends the SMS and
/// checks the code; this controller never sees the code except to pass it to
/// Firebase. The backend then verifies the resulting ID token and issues its
/// own session, which is the credential the app actually uses.
///
/// There is no password. Password login remains available on the backend for
/// recyclers; a collector account has no password hash, and
/// `POST /api/auth/login` answers FIREBASE_SIGN_IN_REQUIRED for one.
///
/// OFFLINE-FIRST (AGENTS.md section 6)
///
/// A phone OTP needs the network, but signing in is not the same as working.
/// If a cached session exists the collector goes straight into the app with
/// no signal and syncs later. Only the OTP steps are blocked offline.
class AuthController extends ChangeNotifier {
  static AuthController? _instance;

  final AuthService _authService;
  final FirebaseAuthService _firebaseAuth;
  final SessionStore _sessionStore;
  final CollectorAuthService _collectorAuth;

  UserProfile? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _pendingPhoneNumber;
  String? _errorMessage;
  bool _phoneAuthAvailable = false;

  /// Firebase's handle for the SMS currently in flight. Memory only: it is a
  /// short-lived session id, not a credential, and persisting it would let a
  /// restored backup resume someone else's sign-in.
  String? _verificationId;

  /// Sign-up draft carried across the OTP screen.
  String? _pendingSignUpName;
  String? _pendingSignUpCity;
  String? _pendingSignUpRole;
  String? _pendingSignUpPhotoPath;

  AuthController({
    AuthService? authService,
    FirebaseAuthService? firebaseAuth,
    SessionStore? sessionStore,
    CollectorAuthService? collectorAuth,
  })  : _authService = authService ?? AuthService.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuthService(),
        _sessionStore = sessionStore ?? SessionStore(),
        _collectorAuth = collectorAuth ??
            CollectorAuthService(
              apiBaseUrl: AppConstants.apiBaseUrl,
              sessionStore: sessionStore ?? SessionStore(),
            );

  static AuthController get instance {
    _instance ??= AuthController();
    return _instance!;
  }

  static void setInstance(AuthController controller) {
    _instance = controller;
  }

  static void resetForTesting() {
    _instance = null;
  }

  UserProfile? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Firebase's handle for the SMS in flight. Null when no code has been
  /// requested yet.
  String? get verificationId => _verificationId;

  /// False when Firebase could not start, so the UI can explain why sign-in
  /// is unavailable instead of failing on the first tap.
  bool get isPhoneAuthAvailable => _phoneAuthAvailable;

  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get pendingSignUpName => _pendingSignUpName;
  String? get pendingSignUpCity => _pendingSignUpCity;
  String? get pendingSignUpRole => _pendingSignUpRole;

  /// True once the collector has a usable profile.
  ///
  /// A backend session alone is not enough: a brand new account still needs a
  /// name and city, and must not land on the home screen before that.
  bool get isAuthenticated =>
      _currentUser != null && _currentUser!.isProfileComplete;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setPendingPhoneNumber(String phone) {
    _pendingPhoneNumber = phone;
    notifyListeners();
  }

  /// Restore any session saved on this device.
  ///
  /// Runs on every cold start. Never contacts the network: the point is to let
  /// a collector with no signal straight into the app.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _phoneAuthAvailable = await FirebaseAuthService.ensureInitialised();

      _currentUser = await _authService.getCurrentUser();

      /*
       | A Firebase session without a local profile means sign-up finished but
       | the collector never completed their details. Keep them in the app so
       | they can finish rather than bouncing to sign-in.
       */
      if (_currentUser == null && await _sessionStore.hasSession()) {
        final session = await _sessionStore.read();

        if (session != null && session.needsProfile) {
          /*
           | Deliberately incomplete rather than a demo profile: the real
           | name and city are unknown until the collector supplies them, and
           | `isProfileComplete: false` routes them to the profile screen
           | instead of letting them onto the home screen as somebody else.
           */
          _currentUser = UserProfile.create(
            name: '',
            phoneNumber: '',
            city: '',
            isProfileComplete: false,
            backendUserId: session.userId,
          );
        }
      }
    } catch (error) {
      developer.log('Could not restore session', name: 'collector.auth', error: error);
      _currentUser = null;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Explicitly set current user (useful for testing or fallback).
  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Remember sign-up details while the collector verifies their number.
  ///
  /// No password is kept: Firebase owns the SMS, so there is nothing for a
  /// local password to protect, and storing one would recreate the reversible
  /// hashing this flow is replacing.
  Future<void> initiateSignUp({
    String? phoneNumber,
    String? phone,
    String? name,
    String? city,
    String? password,
    String role = 'collector',
    String? photoPath,
  }) async {
    _pendingPhoneNumber = phoneNumber ?? phone;
    _pendingSignUpName = name;
    _pendingSignUpCity = city;
    _pendingSignUpRole = role;
    _pendingSignUpPhotoPath = photoPath;
    _errorMessage = null;

    notifyListeners();

    await sendOtp(_pendingPhoneNumber!);
  }

  /// Ask Firebase to text a code to [phoneNumber].
  ///
  /// Requires connectivity: this is the one step offline-first cannot cover.
  /// Returns false and sets [errorMessage] on failure.
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();

    try {
      final normalised = normaliseIndianPhone(phoneNumber);

      if (normalised == null) {
        _errorMessage = 'invalidPhoneLength';
        return false;
      }

      _verificationId = await _firebaseAuth.requestCode(normalised);

      return true;
    } on PhoneAuthException catch (error) {
      developer.log(
        'Could not request a phone code',
        name: 'collector.auth',
        error: error.reason,
      );

      _errorMessage = error.messageKey;

      return false;
    } catch (error, stack) {
      developer.log(
        'Unexpected failure requesting a phone code',
        name: 'collector.auth',
        error: error,
        stackTrace: stack,
      );

      _errorMessage = 'authErrorUnknown';

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resend the SMS. Firebase rate-limits this heavily, so the UI must make
  /// the wait explicit rather than letting a collector tap repeatedly.
  Future<bool> resendOtp() async {
    final phone = _pendingPhoneNumber;

    if (phone == null) {
      _errorMessage = 'authErrorUnknown';
      notifyListeners();

      return false;
    }

    return sendOtp(phone);
  }

  /// Verify the SMS code with Firebase, then exchange the resulting ID token
  /// for a backend session.
  ///
  /// [otp] is the code the collector typed. It goes to Firebase and nowhere
  /// else — the backend never receives it.
  Future<AuthVerificationResult> verifyOtp(
    String otp, {
    String? phoneNumber,
  }) async {
    final pendingVerificationId = _verificationId;

    if (pendingVerificationId == null) {
      _errorMessage = 'authErrorSessionExpired';
      notifyListeners();

      return const AuthVerificationResult(success: false);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final identity = await _firebaseAuth.verifyCode(
        verificationId: pendingVerificationId,
        smsCode: otp,
      );

      // Firebase has now proved control of the number. The backend decides
      // what that is worth.
      final exchange = await _collectorAuth.exchangeFirebaseToken(
        firebaseIdToken: identity.idToken,
        fullName: _pendingSignUpName,
      );

      final session = exchange.session;

      _currentUser = await _authService.completeUserProfile(
        phoneNumber: phoneNumber ?? _pendingPhoneNumber!,
        name: _pendingSignUpName ?? '',
        city: _pendingSignUpCity ?? '',
        role: session.role == 'COLLECTOR'
            ? 'collector'
            : session.role.toLowerCase(),
        photoPath: _pendingSignUpPhotoPath,
        backendUserId: session.userId,
      );

      // The Firebase session has done its job. Dropping it means the next
      // sign-in has to re-verify the number rather than relying on a token
      // Firebase may keep alive on the device.
      await _firebaseAuth.signOut();
      _verificationId = null;

      return AuthVerificationResult(
        success: true,
        isNewUser: exchange.created,
        user: _currentUser,
      );
    } on PhoneAuthException catch (error) {
      _errorMessage = error.messageKey;

      return AuthVerificationResult(
        success: false,
        errorMessage: error.messageKey,
      );
    } on SessionExchangeException catch (error) {
      developer.log(
        'Backend rejected the sign-in exchange',
        name: 'collector.auth',
        error: error.reason,
      );

      _errorMessage = error.messageKey;

      return AuthVerificationResult(
        success: false,
        errorMessage: error.messageKey,
      );
    } catch (error, stack) {
      developer.log(
        'Unexpected failure during sign-in',
        name: 'collector.auth',
        error: error,
        stackTrace: stack,
      );

      _errorMessage = 'authErrorUnknown';

      return const AuthVerificationResult(success: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Finish a partially completed profile.
  Future<UserProfile> completeProfile({
    required String name,
    required String city,
    String? photoPath,
  }) async {
    final current = _currentUser;
    final phone = current?.phoneNumber ?? _pendingPhoneNumber;

    if (phone == null || phone.isEmpty) {
      throw StateError('Cannot complete a profile without a phone number');
    }

    final updated = await _authService.completeUserProfile(
      phoneNumber: phone,
      name: name,
      city: city,
      role: current?.role ?? 'collector',
      photoPath: photoPath,
      backendUserId: current?.backendUserId,
    );

    _currentUser = updated;
    notifyListeners();

    return updated;
  }

  /// Persist profile edits.
  Future<UserProfile> updateProfile(UserProfile updatedUser) async {
    final saved = await _authService.updateUserProfile(updatedUser);

    _currentUser = saved;
    notifyListeners();

    return saved;
  }

  /// Sign out everywhere on this device.
  ///
  /// Local state is cleared even if the backend is unreachable, so tapping
  /// sign out always ends up signed out.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseAuth.signOut();
      await _collectorAuth.signOut();
      await _authService.logout();
    } catch (error) {
      developer.log('Sign-out did not complete cleanly', name: 'collector.auth', error: error);
    } finally {
      _currentUser = null;
      _pendingPhoneNumber = null;
      _verificationId = null;
      _pendingSignUpName = null;
      _pendingSignUpCity = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}