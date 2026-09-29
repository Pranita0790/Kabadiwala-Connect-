import 'package:uuid/uuid.dart';

/// User profile model for Kabadiwala Connect.
/// Supports both scrap collectors (informal kabadiwalas) and recyclers.
/// Persisted locally in SQLite for offline-first operation.
class UserProfile {
  final String id;
  final String name;
  final String phoneNumber;
  final String? passwordHash;
  final String city;
  final String role; // 'collector' or 'recycler'
  final String? photoPath;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.passwordHash,
    required this.city,
    this.role = 'collector',
    this.photoPath,
    this.isProfileComplete = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory to create a new user profile with a generated UUID
  factory UserProfile.create({
    String? id,
    required String name,
    required String phoneNumber,
    String? passwordHash,
    required String city,
    String role = 'collector',
    String? photoPath,
    bool isProfileComplete = true,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: id ?? const Uuid().v4(),
      name: name,
      phoneNumber: phoneNumber,
      passwordHash: passwordHash,
      city: city,
      role: role,
      photoPath: photoPath,
      isProfileComplete: isProfileComplete,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Default demo/guest collector profile for instant testing and fallback
  static UserProfile defaultCollector() {
    final now = DateTime.now();
    return UserProfile(
      id: 'demo_collector_1',
      name: 'Ramesh Shinde',
      phoneNumber: '+91 98765 43210',
      passwordHash: null,
      city: 'Pune',
      role: 'collector',
      photoPath: null,
      isProfileComplete: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get isCollector => role.toLowerCase() == 'collector' || role.toLowerCase() == 'scrap_collector';
  bool get isRecycler => role.toLowerCase() == 'recycler';

  String get initials {
    if (name.trim().isEmpty) return 'K';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String get formattedPhone {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return '+91 ${digitsOnly.substring(2, 7)} ${digitsOnly.substring(7)}';
    } else if (digitsOnly.length == 10) {
      return '+91 ${digitsOnly.substring(0, 5)} ${digitsOnly.substring(5)}';
    }
    return phoneNumber;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'password_hash': passwordHash,
      'city': city,
      'role': role,
      'photo_path': photoPath,
      'is_profile_complete': isProfileComplete ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      passwordHash: map['password_hash'] as String?,
      city: map['city'] as String? ?? '',
      role: map['role'] as String? ?? 'collector',
      photoPath: map['photo_path'] as String?,
      isProfileComplete: (map['is_profile_complete'] == 1 || map['is_profile_complete'] == true),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? passwordHash,
    String? city,
    String? role,
    String? photoPath,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      passwordHash: passwordHash ?? this.passwordHash,
      city: city ?? this.city,
      role: role ?? this.role,
      photoPath: photoPath ?? this.photoPath,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
