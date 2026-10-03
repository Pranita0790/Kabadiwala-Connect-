class EWasteLot {
  final String id;
  final String categoryId;
  final String categoryName;
  final double weightKg;
  final String condition;
  final String? imagePath;
  final String? notes;
  final double estimatedMinPrice;
  final double estimatedMaxPrice;
  final String status;
  final String syncStatus; // 'PENDING_SYNC', 'SYNCING', 'SYNCED', 'FAILED'
  final DateTime createdAt;
  final DateTime updatedAt;

  String get category => categoryName.isNotEmpty ? categoryName : categoryId;
  double get weight => weightKg;

  EWasteLot({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.weightKg,
    required this.condition,
    this.imagePath,
    this.notes,
    required this.estimatedMinPrice,
    required this.estimatedMaxPrice,
    required this.status,
    required this.syncStatus,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'category': categoryName,
      'category_id': categoryId,
      'category_name': categoryName,
      'weight': weightKg,
      'weight_kg': weightKg,
      'condition': condition,
      'notes': notes,
      'estimated_min_price': estimatedMinPrice,
      'estimated_max_price': estimatedMaxPrice,
      'status': status,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EWasteLot.fromMap(Map<String, dynamic> map) {
    final catName = (map['category'] ?? map['category_name'] ?? map['category_id'] ?? '') as String;
    final catId = (map['category_id'] ?? map['category'] ?? '') as String;
    final w = ((map['weight'] ?? map['weight_kg'] ?? 0.0) as num).toDouble();
    return EWasteLot(
      id: map['id'] as String,
      categoryId: catId.isNotEmpty ? catId : catName,
      categoryName: catName.isNotEmpty ? catName : catId,
      weightKg: w,
      condition: (map['condition'] as String?) ?? 'good',
      imagePath: map['image_path'] as String?,
      notes: map['notes'] as String?,
      estimatedMinPrice: ((map['estimated_min_price'] ?? 0.0) as num).toDouble(),
      estimatedMaxPrice: ((map['estimated_max_price'] ?? 0.0) as num).toDouble(),
      status: (map['status'] as String?) ?? 'CREATED',
      syncStatus: (map['sync_status'] as String?) ?? 'PENDING_SYNC',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  EWasteLot copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    double? weightKg,
    String? condition,
    String? imagePath,
    String? notes,
    double? estimatedMinPrice,
    double? estimatedMaxPrice,
    String? status,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EWasteLot(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      weightKg: weightKg ?? this.weightKg,
      condition: condition ?? this.condition,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      estimatedMinPrice: estimatedMinPrice ?? this.estimatedMinPrice,
      estimatedMaxPrice: estimatedMaxPrice ?? this.estimatedMaxPrice,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
