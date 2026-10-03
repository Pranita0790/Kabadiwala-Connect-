import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'backend_api_client.dart';
import 'database_service.dart';

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
  static const String _kBackendUserId = 'auth_backend_user_id';

  final DatabaseService _dbService;
  final BackendApiClient _backend;

  // In-memory OTP storage for current sign up session
  String? _lastGeneratedOtp;
  String? _lastPhoneSent;
  DateTime? _lastOtpSentTime;

  AuthService({DatabaseService? dbService, BackendApiClient? backendClient})
      : _dbService = dbService ?? DatabaseService.instance,
        _backend = backendClient ?? BackendApiClient.instance;

  bool get _remoteEnabled => BackendApiClient.remoteEnabled;

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

  /// Logs in an existing user with mobile number and password (NO OTP).
  ///
  /// Online, the credentials are verified by the backend and the issued
  /// session tokens are stored locally. If the backend is unreachable, the
  /// locally cached password hash is used so an existing collector can still
  /// sign in offline (offline-first).
  Future<AuthVerificationResult> loginWithPassword({
    required String rawPhone,
    required String password,
  }) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);

    if (_remoteEnabled) {
      final remote = await _backend.post(
        '/auth/login',
        body: {'identifier': cleanPhone, 'password': password},
      );

      if (remote.success) {
        await _persistRemoteSession(remote);
        final user = await _upsertLocalUserFromRemote(
          remote.data is Map ? (remote.data['user'] as Map?) : null,
          rawPhone: cleanPhone,
          password: password,
        );
        return AuthVerificationResult(
          success: true,
          isNewUser: false,
          user: user,
        );
      }

      // The backend answered and rejected the credentials. Do not let a stale
      // local hash authenticate a user the server refused.
      if (!remote.isNetworkError) {
        return const AuthVerificationResult(
          success: false,
          errorMessage: 'invalidCredentialsError',
        );
      }
      // Network failure -> fall through to the offline credential check.
    }

    return _offlinePasswordLogin(cleanPhone, password);
  }

  Future<AuthVerificationResult> _offlinePasswordLogin(
    String cleanPhone,
    String password,
  ) async {
    final user = await _dbService.getUserByPhone(cleanPhone);

    if (user == null) {
      return const AuthVerificationResult(
        success: false,
        errorMessage: 'invalidCredentialsError',
      );
    }

    // Verify password if hash exists on user profile
    if (user.passwordHash != null && user.passwordHash!.isNotEmpty) {
      final expectedHash = hashPassword(password);
      if (user.passwordHash != expectedHash) {
        return const AuthVerificationResult(
          success: false,
          errorMessage: 'invalidCredentialsError',
        );
      }
    }

    // Password valid -> persist session
    await _dbService.setCurrentUserId(user.id);

    return AuthVerificationResult(
      success: true,
      isNewUser: false,
      user: user,
    );
  }

  /// Stores the backend session tokens and the backend user id locally.
  Future<void> _persistRemoteSession(ApiResult result) async {
    final data = result.data;
    if (data is! Map) return;

    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null && refresh != null) {
      await _backend.saveTokens(accessToken: access, refreshToken: refresh);
    }

    final user = data['user'];
    if (user is Map && user['id'] is String) {
      await _dbService.saveSetting(_kBackendUserId, user['id'] as String);
    }
  }

  /// Creates or refreshes the local SQLite profile from a backend user DTO.
  Future<UserProfile> _upsertLocalUserFromRemote(
    Map? remoteUser, {
    required String rawPhone,
    String? password,
    String? city,
    String role = 'collector',
    String? photoPath,
  }) async {
    final cleanPhone = normalizePhoneNumber(rawPhone);
    final existing = await _dbService.getUserByPhone(cleanPhone);

    final backendId = remoteUser?['id'] as String?;
    if (backendId != null) {
      await _dbService.saveSetting(_kBackendUserId, backendId);
    }

    final backendName = (remoteUser?['fullName'] as String?)?.trim();

    final user = UserProfile.create(
      id: existing?.id,
      name: (backendName != null && backendName.isNotEmpty)
          ? backendName
          : (existing?.name ?? ''),
      phoneNumber: (remoteUser?['phone'] as String?) ?? cleanPhone,
      passwordHash: (password != null && password.isNotEmpty)
          ? hashPassword(password)
          : existing?.passwordHash,
      city: city ?? existing?.city ?? '',
      role: ((remoteUser?['role'] as String?) ?? role).toLowerCase(),
      photoPath: photoPath ?? existing?.photoPath,
      isProfileComplete: true,
    );

    await _dbService.saveUser(user);
    await _dbService.setCurrentUserId(user.id);
    return user;
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

    // Offline-first: persist the account locally before touching the network.
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

    if (_remoteEnabled) {
      // Register the collector (201) then sign in to obtain a session. If the
      // account already exists on the server (e.g. created on another device)
      // we still try to sign in with the supplied password.
      final register = await _backend.post('/auth/register', body: {
        'fullName': name.trim(),
        'phone': cleanPhone,
        'password': password,
        'role': 'COLLECTOR',
      });

      if (register.success || register.code == 'ACCOUNT_EXISTS') {
        final login = await _backend.post('/auth/login', body: {
          'identifier': cleanPhone,
          'password': password,
        });

        if (login.success) {
          await _persistRemoteSession(login);
          return _upsertLocalUserFromRemote(
            login.data is Map ? (login.data['user'] as Map?) : null,
            rawPhone: cleanPhone,
            password: password,
            city: city.trim(),
            role: role,
            photoPath: photoPath ?? existing?.photoPath,
          );
        }
      } else if (register.isNetworkError) {
        debugPrint('Backend registration unavailable; kept local account.');
      } else {
        debugPrint(
          'Backend registration rejected (${register.code}): ${register.message}',
        );
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

  /// Fetches currently authenticated user
  Future<UserProfile?> getCurrentUser() async {
    return await _dbService.getCurrentUser();
  }

  /// Logs out the user and clears the local and remote session.
  Future<void> logout() async {
    if (_remoteEnabled && _backend.refreshToken != null) {
      try {
        await _backend.post(
          '/auth/logout',
          body: {'refreshToken': _backend.refreshToken},
        );
      } catch (_) {
        // Best effort: clearing the local session must always succeed.
      }
    }

    await _backend.clearTokens();
    await _dbService.deleteSetting(_kBackendUserId);
    await _dbService.clearAuthSession();
    _lastGeneratedOtp = null;
    _lastPhoneSent = null;
  }
}
