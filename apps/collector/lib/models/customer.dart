class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double latitude;
  final double longitude;
  final int totalPickups;
  final double totalWeightKg;
  final double totalPaid;
  final DateTime? lastPickupAt;
  final DateTime createdAt;
  final bool isRegular;
  final String? userPublicId;
  final DateTime? lastReminderAt;
  /// From loyalty API: WEEK / MONTH when inactive.
  final String? suggestedCadence;
  final int? daysInactive;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.latitude = 18.5204,
    this.longitude = 73.8567,
    this.totalPickups = 0,
    this.totalWeightKg = 0.0,
    this.totalPaid = 0.0,
    this.lastPickupAt,
    DateTime? createdAt,
    this.isRegular = false,
    this.userPublicId,
    this.lastReminderAt,
    this.suggestedCadence,
    this.daysInactive,
  }) : createdAt = createdAt ?? DateTime.now();

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    int? totalPickups,
    double? totalWeightKg,
    double? totalPaid,
    DateTime? lastPickupAt,
    DateTime? createdAt,
    bool? isRegular,
    String? userPublicId,
    DateTime? lastReminderAt,
    String? suggestedCadence,
    int? daysInactive,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalPickups: totalPickups ?? this.totalPickups,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      totalPaid: totalPaid ?? this.totalPaid,
      lastPickupAt: lastPickupAt ?? this.lastPickupAt,
      createdAt: createdAt ?? this.createdAt,
      isRegular: isRegular ?? this.isRegular,
      userPublicId: userPublicId ?? this.userPublicId,
      lastReminderAt: lastReminderAt ?? this.lastReminderAt,
      suggestedCadence: suggestedCadence ?? this.suggestedCadence,
      daysInactive: daysInactive ?? this.daysInactive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'total_pickups': totalPickups,
      'total_weight_kg': totalWeightKg,
      'total_paid': totalPaid,
      'last_pickup_at': lastPickupAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_regular': isRegular ? 1 : 0,
      'user_public_id': userPublicId,
      'last_reminder_at': lastReminderAt?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Customer',
      phone: map['phone']?.toString() ?? map['phone_number']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 18.5204,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 73.8567,
      totalPickups: (map['total_pickups'] as num?)?.toInt() ?? 0,
      totalWeightKg: (map['total_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      lastPickupAt: map['last_pickup_at'] != null
          ? DateTime.tryParse(map['last_pickup_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRegular: map['is_regular'] == 1 ||
          map['is_regular'] == true ||
          map['isRegular'] == true,
      userPublicId: map['user_public_id']?.toString() ??
          map['userPublicId']?.toString() ??
          map['userId']?.toString(),
      lastReminderAt: map['last_reminder_at'] != null
          ? DateTime.tryParse(map['last_reminder_at'].toString())
          : (map['lastReminderAt'] != null
              ? DateTime.tryParse(map['lastReminderAt'].toString())
              : null),
      suggestedCadence: map['suggestedCadence']?.toString(),
      daysInactive: (map['daysInactive'] as num?)?.toInt(),
    );
  }
}
