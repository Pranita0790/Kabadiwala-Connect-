import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'session_store.dart';

class AuthVerificationResult {
  final bool success;
  final bool isNewUser;
  final UserProfile? user;
  final String? errorMessage;

  const AuthVerificationResult({
    required this.success,
    this.isNewUser = false,
    this.user,
    this.errorMessage,
  });
}

/// Offline-first Authentication Service.
/// Handles password login, OTP simulation for sign up, and user management with SQLite.
class AuthService {
  static AuthService? _instance;
  final DatabaseService _dbService;
  final RemoteApiService _api;
  final SessionStore _sessionStore;

  // In-memory OTP storage for current sign up session
  String? _lastGeneratedOtp;
  String? _lastPhoneSent;
  DateTime? _lastOtpSentTime;

  AuthService({
    DatabaseService? dbService,
    RemoteApiService? apiService,
    SessionStore? sessionStore,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _api = apiService ?? RemoteApiService.instance,
        _sessionStore = sessionStore ?? SessionStore();

  static AuthService get instance {
    _instance ??= AuthService();
    return _instance!;
  }

  String? get lastGeneratedOtp => _lastGeneratedOtp;
  String? get lastPhoneSent => _lastPhoneSent;
  DateTime? get lastOtpSentTime => _lastOtpSentTime;

  /// Hashes password deterministically for offline storage
  static String hashPassword(String password) {
    final bytes = utf8.encode('sih26_kconnect_salt_${password.trim()}');
    return base64Url.encode(bytes);
  }

  /// Validates and cleans 10-digit Indian phone number
  static String? validateIndianMobile(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'emptyPhone';
    }
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      if (['6', '7', '8', '9'].contains(digits[0])) {
        return null;
      }
      return 'invalidStartDigit';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      if (['6', '7', '8', '9'].contains(digits[2])) {
        return null;
      }
      return 'invalidStartDigit';
    }
    return 'invalidPhoneLength';
  }

  /// Validates password length and presence
  static String? validatePassword(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'emptyPassword';
    }
    if (input.trim().length < 6) {
      return 'passwordLengthError';
    }
    return null;
  }

  /// Normalizes phone number into standard '+91XXXXXXXXXX'
  static String normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return input.trim();
  }

  /// Checks if a mobile number is already registered in local SQLite
  Future<bool> checkUserExists(String rawPhone) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);
    final user = await _dbService.getUserByPhone(cleanPhone);
    return user != null && user.isProfileComplete;
  }

  /// Restores a previously saved backend JWT onto [RemoteApiService].
  Future<void> restoreBackendSession() async {
    final token = await _sessionStore.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _api.setAuthToken(token);
    }
  }

  /// Logs in an existing user with mobile number and password (NO OTP)
  Future<AuthVerificationResult> loginWithPassword({
    required String rawPhone,
    required String password,
  }) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);

    // Prefer the platform backend so lots/handovers sync to the recycler dashboard.
    final remote = await _api.loginWithPassword(
      identifier: cleanPhone,
      password: password,
    );

    if (remote.success && remote.data != null) {
      final data = remote.data!;
      final access = data['accessToken'] as String? ?? '';
      final refresh = data['refreshToken'] as String?;
      final remoteUser = data['user'] as Map<String, dynamic>?;
      final backendUserId = remoteUser?['id']?.toString();

      await _sessionStore.save(
        accessToken: access,
        refreshToken: refresh,
        userId: backendUserId,
      );
      _api.setAuthToken(access);

      final local = await _dbService.getUserByPhone(cleanPhone);
      final profile = UserProfile.create(
        id: local?.id,
        name: (remoteUser?['fullName'] as String?)?.trim().isNotEmpty == true
            ? remoteUser!['fullName'] as String
            : (local?.name ?? 'Collector'),
        phoneNumber: cleanPhone,
        passwordHash: hashPassword(password),
        city: local?.city ?? '',
        role: 'collector',
        photoPath: local?.photoPath,
        isProfileComplete: true,
      );
      await _dbService.saveUser(profile);
      await _dbService.setCurrentUserId(profile.id);

      return AuthVerificationResult(
        success: true,
        isNewUser: false,
        user: profile,
      );
    }

    // Offline / backend-down fallback: local SQLite password check only.
    final user = await _dbService.getUserByPhone(cleanPhone);

    if (user == null) {
      return AuthVerificationResult(
        success: false,
        errorMessage: remote.errorMessage ?? 'invalidCredentialsError',
      );
    }

    if (user.passwordHash != null && user.passwordHash!.isNotEmpty) {
      final expectedHash = hashPassword(password);
      if (user.passwordHash != expectedHash) {
        return const AuthVerificationResult(
          success: false,
          errorMessage: 'invalidCredentialsError',
        );
      }
    }

    await _dbService.setCurrentUserId(user.id);

    return AuthVerificationResult(
      success: true,
      isNewUser: false,
      user: user,
    );
  }

  /// Sends a simulated/mock OTP during SIGN UP verification only
  Future<String> sendOtp(String rawPhone) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);
    
    // Generate 6-digit OTP (deterministic/demo friendly)
    // Always permit '123456' as universal test OTP
    final rng = Random();
    final generated = (100000 + rng.nextInt(900000)).toString();
    _lastGeneratedOtp = generated;
    _lastPhoneSent = cleanPhone;
    _lastOtpSentTime = DateTime.now();

    debugPrint('=== [SIGN-UP OTP DISPATCHED] ===');
    debugPrint('Phone: $cleanPhone');
    debugPrint('Generated OTP: $generated (Universal demo OTP: 123456)');
    debugPrint('================================');

    return generated;
  }

  /// Verifies OTP for Sign Up
  Future<AuthVerificationResult> verifyOtp({
    required String rawPhone,
    required String enteredOtp,
  }) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);
    final trimmedOtp = enteredOtp.trim();

    if (trimmedOtp.length != 6) {
      return const AuthVerificationResult(
        success: false,
        errorMessage: 'otpMustBe6Digits',
      );
    }

    // Accept generated OTP or universal demo OTP '123456'
    final isValidOtp = (trimmedOtp == '123456') ||
        (trimmedOtp == _lastGeneratedOtp && _lastPhoneSent == cleanPhone);

    if (!isValidOtp) {
      return const AuthVerificationResult(
        success: false,
        errorMessage: 'incorrectOtp',
      );
    }

    final existingUser = await _dbService.getUserByPhone(cleanPhone);

    return AuthVerificationResult(
      success: true,
      isNewUser: existingUser == null || !existingUser.isProfileComplete,
      user: existingUser,
    );
  }

  /// Creates and saves a new user account with password after OTP verification
  Future<UserProfile> createAccountWithPassword({
    required String name,
    String? rawPhone,
    String? phoneNumber,
    String? phone,
    required String password,
    required String city,
    String role = 'collector',
    String? photoPath,
  }) async {
    final inputPhone = rawPhone ?? phoneNumber ?? phone ?? '';
    final cleanPhone = normalizePhoneNumber(inputPhone);
    final existing = await _dbService.getUserByPhone(cleanPhone);

    final user = UserProfile.create(
      id: existing?.id,
      name: name.trim(),
      phoneNumber: cleanPhone,
      passwordHash: hashPassword(password),
      city: city.trim(),
      role: role,
      photoPath: photoPath ?? existing?.photoPath,
      isProfileComplete: true,
    );

    await _dbService.saveUser(user);
    await _dbService.setCurrentUserId(user.id);

    // Mirror the account onto the backend so later password login can sync lots.
    if (password.trim().length >= 8) {
      final registered = await _api.registerCollector(
        fullName: name.trim(),
        phone: cleanPhone,
        password: password,
      );
      if (registered.success) {
        final login = await _api.loginWithPassword(
          identifier: cleanPhone,
          password: password,
        );
        if (login.success && login.data != null) {
          final data = login.data!;
          await _sessionStore.save(
            accessToken: data['accessToken'] as String? ?? '',
            refreshToken: data['refreshToken'] as String?,
            userId: (data['user'] as Map?)?['id']?.toString(),
          );
          _api.setAuthToken(data['accessToken'] as String?);
        }
      }
    }

    return user;
  }

  /// Saves a newly created or completed user profile
  Future<UserProfile> completeUserProfile({
    required String phoneNumber,
    required String name,
    required String city,
    String role = 'collector',
    String? photoPath,
    String? password,
  }) async {
    final cleanPhone = normalizePhoneNumber(phoneNumber);
    final existing = await _dbService.getUserByPhone(cleanPhone);

    final user = UserProfile.create(
      id: existing?.id,
      name: name.trim(),
      phoneNumber: cleanPhone,
      passwordHash: password != null && password.isNotEmpty
          ? hashPassword(password)
          : existing?.passwordHash,
      city: city.trim(),
      role: role,
      photoPath: photoPath ?? existing?.photoPath,
      isProfileComplete: true,
    );

    await _dbService.saveUser(user);
    await _dbService.setCurrentUserId(user.id);
    return user;
  }

  /// Updates an existing user profile
  Future<UserProfile> updateUserProfile(UserProfile updatedUser) async {
    await _dbService.saveUser(updatedUser);
    return updatedUser;
  }

  /// Looks up a profile already saved on this device by phone number.
  ///
  /// Used when the backend returns a session but no local details: whatever the
  /// collector already told us about themselves is reused rather than making
  /// them type it again.
  Future<UserProfile?> findByPhone(String phoneNumber) async {
    final cleanPhone = normalizePhoneNumber(phoneNumber);
    return _dbService.getUserByPhone(cleanPhone);
  }

  /// Fetches currently authenticated user
  Future<UserProfile?> getCurrentUser() async {
    return await _dbService.getCurrentUser();
  }

  /// Logs out the user and clears session
  Future<void> logout() async {
    await _sessionStore.clear();
    _api.setAuthToken(null);
    await _dbService.clearAuthSession();
    _lastGeneratedOtp = null;
    _lastPhoneSent = null;
  }
}
