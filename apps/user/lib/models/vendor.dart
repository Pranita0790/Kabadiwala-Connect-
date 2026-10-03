class VendorRateItem {
  final String id;
  final String materialName;
  final String materialCategory;
  final double ratePerKg;
  final String unit;

  const VendorRateItem({
    required this.id,
    required this.materialName,
    required this.materialCategory,
    required this.ratePerKg,
    this.unit = 'kg',
  });

  factory VendorRateItem.fromJson(Map<String, dynamic> json) {
    return VendorRateItem(
      id: json['id']?.toString() ??
          '${json['materialName']}_${json['materialCategory']}',
      materialName: json['materialName']?.toString() ??
          json['materialCategory']?.toString() ??
          'Scrap',
      materialCategory: json['materialCategory']?.toString() ?? 'Other',
      ratePerKg: (json['ratePerKg'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'kg',
    );
  }
}

class Vendor {
  final String id;
  final String name;
  final String location;
  final double distanceKm;
  final double rating;
  final String phone;
  final String address;
  final List<String> acceptedMaterials;
  final Map<String, double> ratesPerKg;
  final List<VendorRateItem> rateCard;
  final bool isConnected;
  final bool isCollector;
  final bool isFavorite;

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
    this.rateCard = const [],
    this.isConnected = false,
    this.isCollector = true,
    this.isFavorite = false,
  });

  String get shopName => '$name · Kabadiwala';
  String get operatingHours => '8:00 AM - 8:00 PM';
  Map<String, double> get rates => ratesPerKg;

  /// Prefer item-level rate card from collector app; else category summary.
  List<MapEntry<String, double>> get displayRates {
    if (rateCard.isNotEmpty) {
      return rateCard
          .map((r) => MapEntry(r.materialName, r.ratePerKg))
          .toList();
    }
    return ratesPerKg.entries.toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Vendor && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Vendor.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseRates(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {
        'Paper': 14.0,
        'Metal': 42.0,
        'Plastic': 22.0,
        'E-waste': 120.0,
        'Other': 15.0,
      };
    }

    List<String> parseMaterials(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const ['Paper', 'Metal', 'Plastic', 'E-waste', 'Other'];
    }

    List<VendorRateItem> parseRateCard(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => VendorRateItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    final address = json['address']?.toString() ??
        json['location']?.toString() ??
        'Pune';
    final city = json['city']?.toString();
    final rateCard = parseRateCard(json['rateCard']);
    var rates = parseRates(json['rates']);
    if (rateCard.isNotEmpty && (json['rates'] == null || rates.isEmpty)) {
      rates = {};
      for (final item in rateCard) {
        final key = item.materialCategory;
        rates[key] = (rates[key] ?? 0) < item.ratePerKg
            ? item.ratePerKg
            : (rates[key] ?? item.ratePerKg);
      }
    }

    return Vendor(
      id: json['id']?.toString() ??
          'v_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Kabadiwala',
      location: city ?? address,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.2,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.7,
      phone: json['phone']?.toString() ?? '',
      address: address,
      acceptedMaterials: parseMaterials(json['acceptedMaterials']),
      ratesPerKg: rates,
      rateCard: rateCard,
      isConnected: json['isConnected'] == true,
      isCollector: json['isCollector'] != false,
      isFavorite: json['isFavorite'] == true,
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
    List<VendorRateItem>? rateCard,
    bool? isConnected,
    bool? isCollector,
    bool? isFavorite,
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
      rateCard: rateCard ?? this.rateCard,
      isConnected: isConnected ?? this.isConnected,
      isCollector: isCollector ?? this.isCollector,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  static List<Vendor> get sampleVendors => const [
        Vendor(
          id: 'v1',
          name: 'Ramesh Shinde',
          location: 'Pune',
          distanceKm: 0.6,
          rating: 4.8,
          phone: '+919876543210',
          address: 'Shop 12, Main Market, Kothrud, Pune',
          acceptedMaterials: ['Paper', 'Metal', 'Plastic', 'E-waste', 'Other'],
          ratesPerKg: {
            'Paper': 14.0,
            'Metal': 42.0,
            'Plastic': 22.0,
            'E-waste': 120.0,
            'Other': 15.0,
          },
          isConnected: false,
          isCollector: true,
        ),
      ];
}
