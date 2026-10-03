import 'package:flutter/foundation.dart';
import '../constants/demo_auth.dart';
import '../../repositories/user_profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/session_store.dart';

class UserAuthController extends ChangeNotifier {
  static final UserAuthController _instance = UserAuthController._internal();
  factory UserAuthController() => _instance;
  UserAuthController._internal();

  final ApiService _api = ApiService.instance;
  final SessionStore _sessionStore = SessionStore();

  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _userPhone = '';
  String _userName = '';
  String? _userId;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get userPhone => _userPhone;
  String get userName => _userName;
  String? get userId => _userId;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _api.restoreSession();
      final saved = await _sessionStore.read();
      final token = saved?['accessToken']?.toString();
      if (token != null && token.isNotEmpty) {
        final me = await _api.fetchMe();
        if (me.success && me.data != null) {
          _applyUser(me.data!);
          _isLoggedIn = true;
        } else if (saved != null) {
          // Offline soft-restore from last session file.
          _userName = saved['fullName']?.toString() ?? '';
          _userPhone = saved['phone']?.toString() ?? '';
          _userId = saved['userId']?.toString();
          _isLoggedIn = _userPhone.isNotEmpty;
          if (_isLoggedIn) {
            _syncLocalProfile();
          }
        }
      }
    } catch (e) {
      debugPrint('UserAuthController.initialize failed: $e');
      _isLoggedIn = false;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String phone, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.login(phone: phone, password: password);
      if (!result.success || result.data == null) {
        _errorMessage = result.errorMessage ?? 'Login failed';
        _isLoggedIn = false;
        return false;
      }
      final user = result.data!['user'];
      if (user is Map) {
        _applyUser(Map<String, dynamic>.from(user));
      } else {
        _userPhone = phone;
        _userName = 'Customer';
      }
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoggedIn = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.register(
        fullName: fullName,
        phone: phone,
        password: password,
      );
      if (!result.success || result.data == null) {
        _errorMessage = result.errorMessage ?? 'Registration failed';
        _isLoggedIn = false;
        return false;
      }
      final user = result.data!['user'];
      if (user is Map) {
        _applyUser(Map<String, dynamic>.from(user));
      } else {
        _userName = fullName;
        _userPhone = phone;
      }
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoggedIn = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Quick Demo Access: register (if needed) + login the labeled USER account.
  Future<bool> signInAsDemoUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      var result = await _api.login(
        phone: DemoUserAuth.phoneNumber,
        password: DemoUserAuth.password,
      );
      if (!result.success || result.data == null) {
        result = await _api.register(
          fullName: DemoUserAuth.name,
          phone: DemoUserAuth.phoneNumber,
          password: DemoUserAuth.password,
        );
      }
      if (!result.success || result.data == null) {
        _errorMessage =
            result.errorMessage ??
            'Demo login needs the backend. Start Node on port 5000.';
        _isLoggedIn = false;
        return false;
      }
      final user = result.data!['user'];
      if (user is Map) {
        _applyUser(Map<String, dynamic>.from(user));
      } else {
        _userName = DemoUserAuth.name;
        _userPhone = DemoUserAuth.phoneNumber;
        _syncLocalProfile();
      }
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoggedIn = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isLoggedIn = false;
    _userPhone = '';
    _userName = '';
    _userId = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _applyUser(Map<String, dynamic> user) {
    _userId = user['id']?.toString();
    _userName = user['fullName']?.toString() ?? 'Customer';
    _userPhone = user['phone']?.toString() ?? '';
    _syncLocalProfile();
  }

  void _syncLocalProfile() {
    final repo = UserProfileRepository();
    final current = repo.profile;
    repo.updateProfile(
      name: _userName.isNotEmpty ? _userName : current.name,
      phone: _userPhone.isNotEmpty ? _userPhone : current.phone,
      email: current.email,
      flatNo: current.flatNo,
      societyName: current.societyName,
      area: current.area,
      city: current.city,
      pincode: current.pincode,
    );
  }
}
