import '../models/user_profile.dart';
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

/// Local profile store for the signed-in collector.
///
/// Firebase owns phone verification and the backend owns the session; this
/// service only persists the collector's profile in SQLite so the app works
/// with no signal. A collector account has no password.
class AuthService {
  static AuthService? _instance;
  final DatabaseService _dbService;

  AuthService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  static AuthService get instance {
    _instance ??= AuthService();
    return _instance!;
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

  /// Saves a newly created or completed user profile.
  ///
  /// No password: Firebase owns SMS verification, so a collector account has
  /// none. [backendUserId] comes from the session exchange and is what lets
  /// API calls name this collector while the device is offline.
  Future<UserProfile> completeUserProfile({
    required String phoneNumber,
    required String name,
    required String city,
    String role = 'collector',
    String? photoPath,
    String? backendUserId,
    bool isProfileComplete = true,
  }) async {
    final cleanPhone = normalizePhoneNumber(phoneNumber);
    final existing = await _dbService.getUserByPhone(cleanPhone);

    final user = UserProfile.create(
      id: existing?.id,
      name: name.trim(),
      phoneNumber: cleanPhone,
      // Any legacy hash is discarded rather than carried forward: the
      // reversible scheme it came from must not survive the migration.
      city: city.trim(),
      role: role,
      photoPath: photoPath ?? existing?.photoPath,
      isProfileComplete: isProfileComplete,
      backendUserId: backendUserId ?? existing?.backendUserId,
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

  /// Logs out the user and clears session.
  Future<void> logout() async {
    await _dbService.clearAuthSession();
  }
}
