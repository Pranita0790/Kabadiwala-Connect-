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
      lastPickupAt: map['last_pickup_at'] != null ? DateTime.parse(map['last_pickup_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
    );
  }
}
