class Kabadiwala {
  final String id;
  final String name;
  final String phone;
  final String location;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double rating;
  final List<String> materialsAccepted;
  final Map<String, double> rates; // material -> rate per kg
  final bool isAvailable;
  final int totalCollections;
  final String? profileImage;

  Kabadiwala({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0.0,
    this.rating = 0.0,
    required this.materialsAccepted,
    this.rates = const {},
    this.isAvailable = true,
    this.totalCollections = 0,
    this.profileImage,
  });

  factory Kabadiwala.fromMap(Map<String, dynamic> map) {
    return Kabadiwala(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      location: map['location'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      distanceKm: map['distance_km'] != null ? (map['distance_km'] as num).toDouble() : 0.0,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : 0.0,
      materialsAccepted: List<String>.from(map['materials_accepted'] ?? []),
      rates: Map<String, double>.from((map['rates'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      isAvailable: map['is_available'] as bool? ?? true,
      totalCollections: map['total_collections'] as int? ?? 0,
      profileImage: map['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'distance_km': distanceKm,
      'rating': rating,
      'materials_accepted': materialsAccepted,
      'rates': rates,
      'is_available': isAvailable,
      'total_collections': totalCollections,
      'profile_image': profileImage,
    };
  }
}
