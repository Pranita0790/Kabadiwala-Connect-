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
    List<String> categories;
    final accepted = map['acceptedCategories'] ?? map['accepted_categories'];
    if (accepted is List) {
      categories = accepted.map((e) => e.toString()).toList();
    } else {
      final categoriesRaw = accepted?.toString() ?? '';
      categories = categoriesRaw.isEmpty
          ? <String>[]
          : categoriesRaw.split(',').map((e) => e.trim()).toList();
    }

    return Recycler(
      id: map['id'].toString(),
      name: (map['name'] ?? map['organisationName'] ?? 'Recycler').toString(),
      address: (map['address'] as String?) ?? '',
      acceptedCategories: categories,
      distanceKm:
          ((map['distance_km'] ?? map['distanceKm'] ?? 0.0) as num).toDouble(),
      isAuthorized: map['is_authorized'] == 1 ||
          map['is_authorized'] == true ||
          map['isAuthorized'] == true,
      rating: ((map['rating'] ?? 4.5) as num).toDouble(),
      contactPhone:
          (map['contact_phone'] ?? map['contactPhone']) as String?,
      latitude: ((map['latitude'] ?? 0.0) as num).toDouble(),
      longitude: ((map['longitude'] ?? 0.0) as num).toDouble(),
      indicativePrice:
          ((map['indicative_price'] ?? map['indicativePrice']) as num?)
              ?.toDouble(),
      unit: map['unit'] as String? ?? 'kg',
      isDemo: map['is_demo'] == 1 ||
          map['is_demo'] == true ||
          map['isDemo'] == true,
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
