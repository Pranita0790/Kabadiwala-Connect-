/// Model representing an authorized or benchmark e-waste recycler.
/// Designed for offline caching, geolocation proximity matching, and material compatibility.
class Recycler {
  final String id;
  final String name;
  final String address;
  final List<String> acceptedCategories;
  final double distanceKm;
  final bool isAuthorized;
  final double rating;
  final String? contactPhone;
  final double latitude;
  final double longitude;
  final double? indicativePrice;
  final String unit;
  final bool isDemo;

  const Recycler({
    required this.id,
    required this.name,
    required this.address,
    required this.acceptedCategories,
    required this.distanceKm,
    required this.isAuthorized,
    this.rating = 4.5,
    this.contactPhone,
    required this.latitude,
    required this.longitude,
    this.indicativePrice,
    this.unit = 'kg',
    this.isDemo = true,
  });

  double get indicativeRatePerKg => indicativePrice ?? 250.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'accepted_categories': acceptedCategories.join(','),
      'distance_km': distanceKm,
      'is_authorized': isAuthorized ? 1 : 0,
      'rating': rating,
      'contact_phone': contactPhone,
      'latitude': latitude,
      'longitude': longitude,
      'indicative_price': indicativePrice,
      'unit': unit,
      'is_demo': isDemo ? 1 : 0,
    };
  }

  factory Recycler.fromMap(Map<String, dynamic> map) {
    final categoriesRaw = map['accepted_categories'] as String? ?? '';
    final categories = categoriesRaw.isEmpty
        ? <String>[]
        : categoriesRaw.split(',').map((e) => e.trim()).toList();

    return Recycler(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      acceptedCategories: categories,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      isAuthorized: (map['is_authorized'] == 1 || map['is_authorized'] == true),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      contactPhone: map['contact_phone'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      indicativePrice: (map['indicative_price'] as num?)?.toDouble(),
      unit: map['unit'] as String? ?? 'kg',
      isDemo: (map['is_demo'] == 1 || map['is_demo'] == true),
    );
  }

  Recycler copyWith({
    String? id,
    String? name,
    String? address,
    List<String>? acceptedCategories,
    double? distanceKm,
    bool? isAuthorized,
    double? rating,
    String? contactPhone,
    double? latitude,
    double? longitude,
    double? indicativePrice,
    String? unit,
    bool? isDemo,
  }) {
    return Recycler(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      acceptedCategories: acceptedCategories ?? this.acceptedCategories,
      distanceKm: distanceKm ?? this.distanceKm,
      isAuthorized: isAuthorized ?? this.isAuthorized,
      rating: rating ?? this.rating,
      contactPhone: contactPhone ?? this.contactPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      indicativePrice: indicativePrice ?? this.indicativePrice,
      unit: unit ?? this.unit,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
