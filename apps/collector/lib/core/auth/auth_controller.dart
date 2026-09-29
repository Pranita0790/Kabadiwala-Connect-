import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';

/// Central reactive controller for authentication, session lifecycle,
/// login, and sign-up state.
class AuthController extends ChangeNotifier {
  static AuthController? _instance;
  final AuthService _authService;

  UserProfile? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _pendingPhoneNumber;
  String? _lastSentOtp;
  String? _errorMessage;

  // Pending sign up registration draft
  String? _pendingSignUpName;
  String? _pendingSignUpPassword;
  String? _pendingSignUpCity;
  String? _pendingSignUpRole;
  String? _pendingSignUpPhotoPath;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService.instance;

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
  bool get isAuthenticated => _currentUser != null && _currentUser!.isProfileComplete;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get lastSentOtp => _lastSentOtp;
  String? get errorMessage => _errorMessage;

  String? get pendingSignUpName => _pendingSignUpName;
  String? get pendingSignUpCity => _pendingSignUpCity;
  String? get pendingSignUpRole => _pendingSignUpRole;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setPendingPhoneNumber(String phone) {
    _pendingPhoneNumber = phone;
    notifyListeners();
  }

  /// Initialize and load saved session from local SQLite database
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUser();
    } catch (e) {
      debugPrint('Error initializing AuthController: $e');
      _currentUser = null;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Explicitly set current user (useful for testing or fallback)
  void setCurrentUser(UserProfile? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Login with mobile number and password (NO OTP required)
  Future<AuthVerificationResult> login({
    String? phoneNumber,
    String? phone,
    required String password,
  }) async {
    final targetPhone = phoneNumber ?? phone ?? '';
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.loginWithPassword(
        rawPhone: targetPhone,
        password: password,
      );

      if (result.success && result.user != null) {
        _currentUser = result.user;
        _errorMessage = null;
      } else {
        _errorMessage = result.errorMessage ?? 'invalidCredentialsError';
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'invalidCredentialsError';
      notifyListeners();
      return const AuthVerificationResult(
        success: false,
        errorMessage: 'invalidCredentialsError',
      );
    }
  }

  /// Initiates sign up: validates, checks for existing user, saves draft, and sends OTP
  Future<bool> initiateSignUp({
    required String name,
    String? phoneNumber,
    String? phone,
    required String password,
    required String city,
    String role = 'collector',
    String? photoPath,
  }) async {
    final targetPhone = phoneNumber ?? phone ?? '';
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check if user already exists
      final exists = await _authService.checkUserExists(targetPhone);
      if (exists) {
        _errorMessage = 'accountAlreadyExists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Cache registration draft in controller
      _pendingSignUpName = name.trim();
      _pendingSignUpPassword = password;
      _pendingSignUpCity = city.trim();
      _pendingSignUpRole = role;
      _pendingSignUpPhotoPath = photoPath;
      _pendingPhoneNumber = targetPhone;

      // 3. Dispatch OTP for sign up verification
      final otp = await _authService.sendOtp(targetPhone);
      _lastSentOtp = otp;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Resends OTP to current pending phone number
  Future<bool> resendSignUpOtp() async {
    if (_pendingPhoneNumber == null || _pendingPhoneNumber!.isEmpty) {
      return false;
    }
    return sendOtp(_pendingPhoneNumber!);
  }

  /// Send OTP to given phone number (used for sign up verification)
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();

    try {
      final otp = await _authService.sendOtp(phoneNumber);
      _lastSentOtp = otp;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify entered OTP during Sign Up
  Future<AuthVerificationResult> verifyOtp(String otp, {String? phoneNumber}) async {
    final phone = phoneNumber ?? _pendingPhoneNumber ?? _currentUser?.phoneNumber ?? '';
    if (phone.isEmpty) {
      return const AuthVerificationResult(
        success: false,
        errorMessage: 'missingPhone',
      );
    }
    _pendingPhoneNumber = phone;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyOtp(
        rawPhone: phone,
        enteredOtp: otp,
      );

      if (result.success) {
        // If we have pending sign-up registration data, create the account now
        if (_pendingSignUpPassword != null && _pendingSignUpName != null) {
          final createdUser = await _authService.createAccountWithPassword(
            name: _pendingSignUpName!,
            rawPhone: phone,
            password: _pendingSignUpPassword!,
            city: _pendingSignUpCity ?? '',
            role: _pendingSignUpRole ?? 'collector',
            photoPath: _pendingSignUpPhotoPath,
          );
          _currentUser = createdUser;
          _clearPendingSignUp();
        } else if (result.user != null) {
          _currentUser = result.user;
        }
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return AuthVerificationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _clearPendingSignUp() {
    _pendingSignUpName = null;
    _pendingSignUpPassword = null;
    _pendingSignUpCity = null;
    _pendingSignUpRole = null;
    _pendingSignUpPhotoPath = null;
  }

  /// Complete profile for user (fallback/supplementary)
  Future<UserProfile> completeProfile({
    required String name,
    required String city,
    String role = 'collector',
    String? photoPath,
  }) async {
    final phone = _pendingPhoneNumber ?? _currentUser?.phoneNumber ?? '';
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _authService.completeUserProfile(
        phoneNumber: phone,
        name: name,
        city: city,
        role: role,
        photoPath: photoPath,
      );
      _currentUser = profile;
      _isLoading = false;
      notifyListeners();
      return profile;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update profile details
  Future<UserProfile> updateProfile(UserProfile updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _authService.updateUserProfile(updatedUser);
      _currentUser = profile;
      _isLoading = false;
      notifyListeners();
      return profile;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Log out user and return to unauthenticated landing
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _pendingPhoneNumber = null;
      _lastSentOtp = null;
      _clearPendingSignUp();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
