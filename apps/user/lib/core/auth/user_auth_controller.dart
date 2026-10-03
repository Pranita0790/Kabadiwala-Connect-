import 'package:flutter/foundation.dart';

class UserAuthController extends ChangeNotifier {
  static final UserAuthController _instance = UserAuthController._internal();
  factory UserAuthController() => _instance;
  UserAuthController._internal();

  bool _isLoggedIn = true; // Default session active once user logs in
  String _userPhone = '+91 98765 43210';
  String _userName = 'Ananya Sharma';

  bool get isLoggedIn => _isLoggedIn;
  String get userPhone => _userPhone;
  String get userName => _userName;

  void login({required String phone, String name = 'Ananya Sharma'}) {
    _isLoggedIn = true;
    _userPhone = phone;
    _userName = name;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
