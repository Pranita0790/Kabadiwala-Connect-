class Vendor {
  final String id;
  final String name;
  final String location;
  final double distanceKm;
  final double rating;
  final String phone;
  final String address;
  final List<String> acceptedMaterials;
  final Map<String, double> ratesPerKg; // Material-specific vendor rates!
  final bool isConnected;

  const Vendor({
    required this.id,
    required this.name,
    required this.location,
    required this.distanceKm,
    required this.rating,
    required this.phone,
    required this.address,
    required this.acceptedMaterials,
    required this.ratesPerKg,
    this.isConnected = false,
  });

  String get shopName => '$name Scrap Depot';
  String get operatingHours => '8:00 AM - 8:00 PM';
  Map<String, double> get rates => ratesPerKg;

  factory Vendor.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseRates(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {'Newspaper': 14.0, 'Cardboard': 10.0, 'Metal': 32.0, 'Plastic': 16.0};
    }

    return Vendor(
      id: json['id']?.toString() ?? 'v_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Kabadiwala',
      location: json['address']?.toString() ?? 'Local Market',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.2,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.7,
      phone: json['phone']?.toString() ?? '+91 98765 43210',
      address: json['address']?.toString() ?? 'Main Market, City',
      acceptedMaterials: const ['Paper', 'Metal', 'Plastic', 'E-Waste'],
      ratesPerKg: parseRates(json['rates']),
      isConnected: json['isConnected'] == true,
    );
  }

  Vendor copyWith({
    String? id,
    String? name,
    String? location,
    double? distanceKm,
    double? rating,
    String? phone,
    String? address,
    List<String>? acceptedMaterials,
    Map<String, double>? ratesPerKg,
    bool? isConnected,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating ?? this.rating,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      acceptedMaterials: acceptedMaterials ?? this.acceptedMaterials,
      ratesPerKg: ratesPerKg ?? this.ratesPerKg,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  static List<Vendor> get sampleVendors => const [
        Vendor(
          id: 'v1',
          name: 'Ramesh Kumar',
          location: 'Dharavi',
          distanceKm: 1.8,
          rating: 4.7,
          phone: '+91 98765 43210',
          address: 'Shop 14, Dharavi Main Rd, Mumbai',
          acceptedMaterials: ['Paper', 'Metal', 'Plastic', 'E-waste'],
          ratesPerKg: {
            'Paper': 12.0,
            'Metal': 42.0,
            'Plastic': 28.0,
            'E-waste': 110.0,
          },
          isConnected: true,
        ),
        Vendor(
          id: 'v2',
          name: 'Vijay Scrap Traders',
          location: 'Kothrud',
          distanceKm: 2.4,
          rating: 4.5,
          phone: '+91 98220 11223',
          address: 'Plot 45, Near Karve Statue, Kothrud, Pune',
          acceptedMaterials: ['Paper', 'Metal', 'Plastic'],
          ratesPerKg: {
            'Paper': 14.0,
            'Metal': 40.0,
            'Plastic': 25.0,
          },
          isConnected: false,
        ),
        Vendor(
          id: 'v3',
          name: 'Anita Waste Solutions',
          location: 'Shivajinagar',
          distanceKm: 3.1,
          rating: 4.8,
          phone: '+91 97654 99887',
          address: '102 FC Road, Shivajinagar, Pune',
          acceptedMaterials: ['Metal', 'E-waste', 'Plastic'],
          ratesPerKg: {
            'Metal': 45.0,
            'E-waste': 125.0,
            'Plastic': 30.0,
          },
          isConnected: false,
        ),
      ];
}
