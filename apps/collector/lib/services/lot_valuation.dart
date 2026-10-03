import '../models/price.dart';
import 'ai_classification_service.dart';

/// Maps AI labels to lot categories and estimates a ₹ range from the rate card.
class LotValuation {
  static const double minAutoSelectConfidence = 0.60;

  static String mapAiMaterialToCategoryId(String material) {
    switch (material.trim().toLowerCase()) {
      case 'pcb':
      case 'pcb_motherboard':
      case 'motherboard':
        return 'pcb_motherboard';
      case 'cable':
      case 'copper_wire':
      case 'copper':
        return 'copper_wire';
      case 'battery':
      case 'batteries':
        return 'battery';
      case 'lcd_panel':
      case 'crt':
      case 'display':
      case 'display_monitor':
        return 'display_monitor';
      case 'motor':
      case 'magnet_bearing_assembly':
      case 'heavy_appliances':
        return 'heavy_appliances';
      case 'mixed_plastics':
      case 'plastic':
        return 'plastic';
      case 'paper':
        return 'paper';
      case 'book':
        return 'book';
      default:
        return 'mixed_ewaste';
    }
  }

  static bool shouldAutoSelect(ClassificationResult result) {
    if (result.isMockResult) return true;
    final material = result.categoryName.trim().toLowerCase();
    if (material == 'unknown' || result.categoryId == 'unknown') {
      return false;
    }
    if (result.isLowConfidence) return false;
    if (result.confidenceScore < minAutoSelectConfidence) return false;
    return true;
  }

  static bool isPotentialCriticalCategory(String categoryId) {
    return categoryId == 'pcb_motherboard' || categoryId == 'battery';
  }

  static double conditionFactor(String condition) {
    switch (condition) {
      case 'good':
        return 1.0;
      case 'average':
        return 0.85;
      case 'scrap':
        return 0.70;
      default:
        return 0.85;
    }
  }

  /// Same ±8% band the backend uses around `ratePerKg` (rates.service.js).
  static const double valueSpread = 0.08;

  /// Parses GET /api/rates (and /api/prices alias) the way the website does.
  static List<Price> pricesFromRatesResponse(dynamic body) {
    if (body is! Map) return const [];
    final rawList = body['data'] is Map
        ? (body['data']['rates'] ?? body['data']['prices'] ?? body['data'])
        : (body['rates'] ?? body['prices'] ?? body['data']);
    if (rawList is! List) return const [];
    final prices = <Price>[];
    for (final item in rawList) {
      if (item is Map) {
        final price = priceFromRateJson(Map<String, dynamic>.from(item));
        if (price != null) prices.add(price);
      }
    }
    return prices;
  }

  static Price? priceFromRateJson(Map<String, dynamic> item) {
    final materialKey = (item['materialId'] ??
            item['material'] ??
            item['id'] ??
            item['publicId'] ??
            '')
        .toString()
        .trim();
    if (materialKey.isEmpty) return null;

    final categoryId = mapAiMaterialToCategoryId(materialKey);
    final displayName = (item['displayName'] ??
            item['materialName'] ??
            item['categoryName'] ??
            item['material'] ??
            materialKey)
        .toString();
    final rate = (item['ratePerKg'] as num?)?.toDouble() ??
        (item['minPrice'] as num?)?.toDouble() ??
        0.0;
    if (rate <= 0) return null;

    final minRate = (item['minPrice'] as num?)?.toDouble();
    final maxRate = (item['maxPrice'] as num?)?.toDouble();
    final minPrice = minRate != null && minRate > 0
        ? minRate
        : (rate * (1 - valueSpread));
    final maxPrice = maxRate != null && maxRate > 0
        ? maxRate
        : (rate * (1 + valueSpread));

    final unitRaw = (item['unit'] ?? 'kg').toString();
    final unit = unitRaw.toLowerCase().contains('kg') ? 'kg' : unitRaw;
    final updated = item['updatedAt'] ?? item['updated_at'];

    return Price(
      id: categoryId,
      categoryId: categoryId,
      material: displayName,
      categoryNameEn: displayName,
      categoryNameHi: (item['categoryNameHi'] ?? displayName).toString(),
      categoryNameMr: (item['categoryNameMr'] ?? displayName).toString(),
      minPrice: minPrice,
      maxPrice: maxPrice,
      unit: unit,
      location: (item['region'] ?? item['location'] ?? 'IN-MH').toString(),
      source: (item['source'] ?? 'Formal Benchmark').toString(),
      updatedAt: updated is String
          ? DateTime.tryParse(updated) ?? DateTime.now()
          : DateTime.now(),
      iconAsset: _iconForCategory(categoryId),
    );
  }

  static String _iconForCategory(String categoryId) {
    switch (categoryId) {
      case 'pcb_motherboard':
        return 'developer_board';
      case 'copper_wire':
        return 'cable';
      case 'battery':
        return 'battery_charging_full';
      case 'display_monitor':
        return 'monitor';
      case 'heavy_appliances':
        return 'kitchen';
      default:
        return 'recycling';
    }
  }

  static (double, double) ratesPerKg(String categoryId, List<Price> prices) {
    Price? match;
    for (final price in prices) {
      if (_priceMatchesCategory(price, categoryId)) {
        match = price;
        break;
      }
    }
    if (match != null) {
      return (match.minPrice, match.maxPrice);
    }
    // Website catalogue has no book/paper row; use plastics / mixed as estimate.
    if (categoryId == 'book' || categoryId == 'paper') {
      for (final fallback in ['plastic', 'mixed_ewaste', 'mixed_plastics']) {
        for (final price in prices) {
          if (_priceMatchesCategory(price, fallback)) {
            return (price.minPrice, price.maxPrice);
          }
        }
      }
    }
    return (50.0, 100.0);
  }

  static (double, double) estimateRange({
    required String categoryId,
    required double weightKg,
    required String condition,
    required List<Price> prices,
  }) {
    final rates = ratesPerKg(categoryId, prices);
    final factor = conditionFactor(condition);
    final min = weightKg * rates.$1 * factor;
    final max = weightKg * rates.$2 * factor;
    if (max < min) {
      return (max, min);
    }
    return (min, max);
  }

  static bool _priceMatchesCategory(Price price, String categoryId) {
    final wanted = categoryId.toLowerCase();
    final candidates = <String>{
      price.id.toLowerCase(),
      price.categoryId.toLowerCase(),
      price.material.toLowerCase(),
    };
    if (candidates.contains(wanted)) return true;

    final aliases = _aliases[wanted] ?? const <String>{};
    for (final alias in aliases) {
      if (candidates.contains(alias)) return true;
    }
    return false;
  }

  static const Map<String, Set<String>> _aliases = {
    'pcb_motherboard': {'pcb', 'motherboard', 'pcb / motherboard', 'pcb_motherboard'},
    'copper_wire': {'cable', 'copper', 'copper wire', 'copper_wire'},
    'battery': {'battery', 'batteries'},
    'display_monitor': {'lcd_panel', 'crt', 'display', 'monitor', 'monitors & displays'},
    'heavy_appliances': {'motor', 'appliances', 'heavy electricals'},
    'plastic': {'mixed_plastics', 'plastic'},
    'paper': {'paper'},
    'book': {'book', 'books'},
    'mixed_ewaste': {
      'mixed',
      'e-waste',
      'mixed e-waste',
      'mixed_plastics',
      'mixed_ewaste',
    },
  };
}
