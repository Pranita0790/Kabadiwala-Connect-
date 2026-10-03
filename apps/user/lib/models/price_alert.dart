/// Model representing a collector's target price alert for a material category.
/// Persisted locally in SQLite and monitored when updated market rates are fetched.
class PriceAlert {
  final String id;
  final String categoryId;
  final String categoryName;
  final double targetPrice;
  final String unit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? triggeredAt;

  const PriceAlert({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.targetPrice,
    this.unit = 'kg',
    this.isActive = true,
    required this.createdAt,
    this.triggeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_name': categoryName,
      'target_price': targetPrice,
      'unit': unit,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'triggered_at': triggeredAt?.toIso8601String(),
    };
  }

  factory PriceAlert.fromMap(Map<String, dynamic> map) {
    return PriceAlert(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String? ?? 'Material',
      targetPrice: (map['target_price'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'kg',
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
      createdAt: DateTime.parse(map['created_at'] as String),
      triggeredAt: map['triggered_at'] != null
          ? DateTime.parse(map['triggered_at'] as String)
          : null,
    );
  }

  PriceAlert copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    double? targetPrice,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? triggeredAt,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      targetPrice: targetPrice ?? this.targetPrice,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
    );
  }
}
