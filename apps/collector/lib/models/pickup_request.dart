class PickupRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String pickupAddress;
  final double latitude;
  final double longitude;
  final String preferredTimeSlot;
  final String materialCategory;
  final String materialName;
  final double estimatedWeightKg;
  final double ratePerKg; // Snapshot rate at request creation
  final String? photoUrl;
  final String? description;
  final String status; // 'PENDING', 'ACCEPTED', 'ON_MY_WAY', 'COLLECTING', 'COMPLETED', 'REJECTED', 'CANCELLED'
  final double? actualWeightKg;
  final double? finalAmount; // Calculated: actualWeightKg * ratePerKg
  final String? paymentMethod; // 'CASH', 'UPI', 'BANK_TRANSFER'
  final String paymentStatus; // 'PENDING', 'PAID'
  final String collectorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  PickupRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickupAddress,
    this.latitude = 18.5204,
    this.longitude = 73.8567,
    required this.preferredTimeSlot,
    required this.materialCategory,
    required this.materialName,
    required this.estimatedWeightKg,
    required this.ratePerKg,
    this.photoUrl,
    this.description,
    this.status = 'PENDING',
    this.actualWeightKg,
    this.finalAmount,
    this.paymentMethod,
    this.paymentStatus = 'PENDING',
    this.collectorId = 'default_collector',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PickupRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    String? pickupAddress,
    double? latitude,
    double? longitude,
    String? preferredTimeSlot,
    String? materialCategory,
    String? materialName,
    double? estimatedWeightKg,
    double? ratePerKg,
    String? photoUrl,
    String? description,
    String? status,
    double? actualWeightKg,
    double? finalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? collectorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return PickupRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
      materialCategory: materialCategory ?? this.materialCategory,
      materialName: materialName ?? this.materialName,
      estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description ?? this.description,
      status: status ?? this.status,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      collectorId: collectorId ?? this.collectorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_phone': userPhone,
      'pickup_address': pickupAddress,
      'latitude': latitude,
      'longitude': longitude,
      'preferred_time_slot': preferredTimeSlot,
      'material_category': materialCategory,
      'material_name': materialName,
      'estimated_weight_kg': estimatedWeightKg,
      'rate_per_kg': ratePerKg,
      'photo_url': photoUrl,
      'description': description,
      'status': status,
      'actual_weight_kg': actualWeightKg,
      'final_amount': finalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'collector_id': collectorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory PickupRequest.fromMap(Map<String, dynamic> map) {
    return PickupRequest(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? map['userName']?.toString() ?? 'Customer',
      userPhone: map['user_phone']?.toString() ?? map['userPhone']?.toString() ?? '',
      pickupAddress: map['pickup_address']?.toString() ?? map['pickupAddress']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 18.5204,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 73.8567,
      preferredTimeSlot: map['preferred_time_slot']?.toString() ?? map['preferredTimeSlot']?.toString() ?? 'Flexible',
      materialCategory: map['material_category']?.toString() ?? map['materialCategory']?.toString() ?? 'E-Waste',
      materialName: map['material_name']?.toString() ?? map['materialName']?.toString() ?? 'Electronics',
      estimatedWeightKg: (map['estimated_weight_kg'] as num?)?.toDouble() ?? (map['estimatedWeightKg'] as num?)?.toDouble() ?? 0.0,
      ratePerKg: (map['rate_per_kg'] as num?)?.toDouble() ?? (map['ratePerKg'] as num?)?.toDouble() ?? 0.0,
      photoUrl: map['photo_url']?.toString() ?? map['photoUrl']?.toString(),
      description: map['description']?.toString(),
      status: map['status']?.toString() ?? 'PENDING',
      actualWeightKg: (map['actual_weight_kg'] as num?)?.toDouble() ?? (map['actualWeightKg'] as num?)?.toDouble(),
      finalAmount: (map['final_amount'] as num?)?.toDouble() ?? (map['finalAmount'] as num?)?.toDouble(),
      paymentMethod: map['payment_method']?.toString() ?? map['paymentMethod']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? map['paymentStatus']?.toString() ?? 'PENDING',
      collectorId: map['collector_id']?.toString() ?? map['collectorId']?.toString() ?? 'default_collector',
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      completedAt: DateTime.tryParse(
        (map['completed_at'] ?? map['completedAt'] ?? '').toString(),
      ),
    );
  }
}
