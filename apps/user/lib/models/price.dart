class Price {
  final String id;
  final String material;
  final double minPrice;
  final double maxPrice;
  final String unit;
  final String location;
  final String source;
  final DateTime updatedAt;

  // Compatibility fields for existing app UI
  final String categoryId;
  final String categoryNameEn;
  final String categoryNameHi;
  final String categoryNameMr;
  final String iconAsset;

  double get minPricePerUnit => minPrice;
  double get maxPricePerUnit => maxPrice;
  DateTime get lastUpdated => updatedAt;

  Price({
    String? id,
    String? material,
    double? minPrice,
    double? maxPrice,
    required this.unit,
    String? location,
    String? source,
    DateTime? updatedAt,
    String? categoryId,
    String? categoryNameEn,
    String? categoryNameHi,
    String? categoryNameMr,
    String? iconAsset,
    double? minPricePerUnit,
    double? maxPricePerUnit,
    DateTime? lastUpdated,
  })  : id = id ?? categoryId ?? material ?? 'price_id',
        material = material ?? categoryNameEn ?? categoryId ?? 'Material',
        minPrice = minPrice ?? minPricePerUnit ?? 0.0,
        maxPrice = maxPrice ?? maxPricePerUnit ?? 0.0,
        location = location ?? 'Local',
        source = source ?? 'Formal Recycler Rate',
        updatedAt = updatedAt ?? lastUpdated ?? DateTime.now(),
        categoryId = categoryId ?? id ?? material ?? 'price_id',
        categoryNameEn = categoryNameEn ?? material ?? 'Material',
        categoryNameHi = categoryNameHi ?? material ?? categoryNameEn ?? 'सामग्री',
        categoryNameMr = categoryNameMr ?? material ?? categoryNameEn ?? 'सामग्री',
        iconAsset = iconAsset ?? 'recycling';

  String getLocalizedName(String langCode) {
    switch (langCode) {
      case 'hi':
        return categoryNameHi;
      case 'mr':
        return categoryNameMr;
      default:
        return categoryNameEn;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material': material,
      'min_price': minPrice,
      'max_price': maxPrice,
      'unit': unit,
      'location': location,
      'source': source,
      'updated_at': updatedAt.toIso8601String(),
      'category_id': categoryId,
      'category_name_en': categoryNameEn,
      'category_name_hi': categoryNameHi,
      'category_name_mr': categoryNameMr,
      'min_price_per_unit': minPrice,
      'max_price_per_unit': maxPrice,
      'icon_asset': iconAsset,
      'last_updated': updatedAt.toIso8601String(),
    };
  }

  factory Price.fromMap(Map<String, dynamic> map) {
    final mat = (map['material'] ?? map['category_name_en'] ?? map['category_id'] ?? map['id'] ?? '') as String;
    final minP = ((map['min_price'] ?? map['min_price_per_unit'] ?? 0.0) as num).toDouble();
    final maxP = ((map['max_price'] ?? map['max_price_per_unit'] ?? 0.0) as num).toDouble();
    final updated = map['updated_at'] != null
        ? DateTime.parse(map['updated_at'] as String)
        : (map['last_updated'] != null ? DateTime.parse(map['last_updated'] as String) : DateTime.now());

    return Price(
      id: (map['id'] ?? map['category_id']) as String?,
      material: mat,
      minPrice: minP,
      maxPrice: maxP,
      unit: (map['unit'] as String?) ?? 'kg',
      location: (map['location'] as String?) ?? 'Local',
      source: (map['source'] as String?) ?? 'Formal Recycler Rate',
      updatedAt: updated,
      categoryId: (map['category_id'] ?? map['id']) as String?,
      categoryNameEn: (map['category_name_en'] ?? mat) as String?,
      categoryNameHi: (map['category_name_hi'] ?? mat) as String?,
      categoryNameMr: (map['category_name_mr'] ?? mat) as String?,
      iconAsset: (map['icon_asset'] as String?) ?? 'recycling',
    );
  }
}
