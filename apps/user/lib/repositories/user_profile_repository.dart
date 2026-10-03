import 'package:flutter/foundation.dart';

class UserProfile {
  final String name;
  final String phone;
  final String email;
  final String flatNo;
  final String societyName;
  final String area;
  final String city;
  final String pincode;

  UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.flatNo,
    required this.societyName,
    required this.area,
    required this.city,
    required this.pincode,
  });

  String get fullAddress => '$flatNo, $societyName, $area, $city - $pincode';

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? flatNo,
    String? societyName,
    String? area,
    String? city,
    String? pincode,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      flatNo: flatNo ?? this.flatNo,
      societyName: societyName ?? this.societyName,
      area: area ?? this.area,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
    );
  }
}

class UserProfileRepository extends ChangeNotifier {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  UserProfile _profile = UserProfile(
    name: 'Ananya Sharma',
    phone: '+91 98765 43210',
    email: 'ananya.sharma@example.com',
    flatNo: 'B-402',
    societyName: 'Green Acres Housing Society',
    area: 'Andheri East',
    city: 'Mumbai',
    pincode: '400069',
  );

  UserProfile get profile => _profile;

  void updateProfile({
    required String name,
    required String phone,
    required String email,
    required String flatNo,
    required String societyName,
    required String area,
    required String city,
    required String pincode,
  }) {
    _profile = UserProfile(
      name: name,
      phone: phone,
      email: email,
      flatNo: flatNo,
      societyName: societyName,
      area: area,
      city: city,
      pincode: pincode,
    );
    notifyListeners();
  }
}
