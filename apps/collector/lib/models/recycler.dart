/// Model representing an authorized or benchmark e-waste/scrap recycler from official MPCB directory.
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
  final String? contactPerson;
  final String? email;
  final String? capacity;
  final String? categoryLabel;
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
    this.rating = 4.7,
    this.contactPhone,
    this.contactPerson,
    this.email,
    this.capacity,
    this.categoryLabel,
    required this.latitude,
    required this.longitude,
    this.indicativePrice,
    this.unit = 'kg',
    this.isDemo = false,
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
      address: (map['address'] ?? map['city'] ?? '').toString(),
      acceptedCategories: categories.where((c) => c.trim().isNotEmpty).toList(),
      distanceKm: _asDouble(map['distance_km'] ?? map['distanceKm'], 0),
      isAuthorized: map['is_authorized'] == 1 ||
          map['is_authorized'] == true ||
          map['isAuthorized'] == true,
      rating: _asDouble(map['rating'], 4.7),
      contactPhone:
          (map['contact_phone'] ?? map['contactPhone'])?.toString(),
      contactPerson:
          (map['contact_person'] ?? map['contactPerson'])?.toString(),
      email: (map['email'])?.toString(),
      capacity: (map['capacity'])?.toString(),
      categoryLabel: (map['category_label'] ?? map['categoryLabel'])?.toString(),
      latitude: _asDouble(map['latitude'], 0),
      longitude: _asDouble(map['longitude'], 0),
      indicativePrice: map['indicative_price'] == null &&
              map['indicativePrice'] == null
          ? null
          : _asDouble(map['indicative_price'] ?? map['indicativePrice'], 0),
      unit: (map['unit'] ?? 'kg').toString(),
      isDemo: map['is_demo'] == 1 ||
          map['is_demo'] == true ||
          map['is_demo'] == '1' ||
          map['isDemo'] == true ||
          map['isDemo'] == 1 ||
          map['isDemo'] == '1',
    );
  }

  static double _asDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
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
    String? contactPerson,
    String? email,
    String? capacity,
    String? categoryLabel,
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
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      capacity: capacity ?? this.capacity,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      indicativePrice: indicativePrice ?? this.indicativePrice,
      unit: unit ?? this.unit,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
