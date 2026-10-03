class CollectorRate {
  final String id;
  final String collectorId;
  final String materialCategory;
  final String materialName;
  final double ratePerKg;
  final String unit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CollectorRate({
    required this.id,
    required this.collectorId,
    required this.materialCategory,
    required this.materialName,
    required this.ratePerKg,
    this.unit = 'kg',
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CollectorRate copyWith({
    String? id,
    String? collectorId,
    String? materialCategory,
    String? materialName,
    double? ratePerKg,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectorRate(
      id: id ?? this.id,
      collectorId: collectorId ?? this.collectorId,
      materialCategory: materialCategory ?? this.materialCategory,
      materialName: materialName ?? this.materialName,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collector_id': collectorId,
      'material_category': materialCategory,
      'material_name': materialName,
      'rate_per_kg': ratePerKg,
      'unit': unit,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CollectorRate.fromMap(Map<String, dynamic> map) {
    return CollectorRate(
      id: map['id']?.toString() ?? '',
      collectorId: map['collector_id']?.toString() ?? 'default_collector',
      materialCategory: map['material_category']?.toString() ?? map['category']?.toString() ?? 'General',
      materialName: map['material_name']?.toString() ?? map['name']?.toString() ?? 'Scrap',
      ratePerKg: (map['rate_per_kg'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit']?.toString() ?? 'kg',
      isActive: map['is_active'] == 1 || map['is_active'] == true || map['isActive'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : DateTime.now(),
    );
  }
}
