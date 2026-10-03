import '../models/price.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/lot_valuation.dart';

class PriceBoardData {
  final List<Price> prices;
  final bool isOffline;
  final DateTime lastUpdated;

  PriceBoardData({
    required this.prices,
    required this.isOffline,
    required this.lastUpdated,
  });
}

class PriceRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;

  PriceRepository({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
  })  : _dbService = dbService ?? DatabaseService(),
        _apiService = apiService ?? RemoteApiService.instance,
        _connectivityService = connectivityService ?? ConnectivityService();

  /// Retrieves market price benchmarks adhering to offline-first design:
  ///
  /// - Online: Fetches latest rates from API and caches them into local SQLite.
  /// - Offline: Reads latest cached prices from SQLite and flags them as cached/offline.
  /// - First-run fallback: Seeds standard formal recycler rates into SQLite if local storage is empty.
  Future<PriceBoardData> fetchPrices({bool forceRefresh = false}) async {
    final isConnected = await _connectivityService.isConnected();

    if (isConnected) {
      try {
        final response = await _apiService.fetchMarketPrices();
        if (response.success &&
            response.data != null &&
            response.data!.isNotEmpty) {
          for (final price in response.data!) {
            await _dbService.insertPrice(price);
          }
          return PriceBoardData(
            prices: response.data!,
            isOffline: false,
            lastUpdated: DateTime.now(),
          );
        }
      } catch (_) {
        // Fallback to SQLite cache on API error
      }
    }

    // Offline / Fallback Flow: Fetch from SQLite
    final localPrices = await _dbService.getPrices();
    if (localPrices.isNotEmpty) {
      return PriceBoardData(
        prices: localPrices,
        isOffline: true,
        lastUpdated: localPrices.first.updatedAt,
      );
    }

    // Seed default baseline prices if SQLite has not yet been populated
    final defaults = defaultPrices();
    for (final price in defaults) {
      await _dbService.insertPrice(price);
    }

    return PriceBoardData(
      prices: defaults,
      isOffline: true,
      lastUpdated: DateTime.now(),
    );
  }

  // Alias for backward compatibility
  Future<List<Price>> getPrices() async {
    final data = await fetchPrices();
    return data.prices;
  }

  static List<Price> defaultPrices() {
    final now = DateTime.now();
    return [
      Price(
        id: 'pcb_motherboard',
        material: 'PCB',
        categoryNameEn: 'PCB / Motherboard',
        categoryNameHi: 'पीसीबी / मदरबोर्ड',
        categoryNameMr: 'पीसीबी / मदरबोर्ड',
        minPrice: 240.0,
        maxPrice: 290.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: now,
        iconAsset: 'developer_board',
      ),
      Price(
        id: 'copper_wire',
        material: 'Copper Wire',
        categoryNameEn: 'Copper Wire',
        categoryNameHi: 'तांबे का तार',
        categoryNameMr: 'तांब्याची तार',
        minPrice: 450.0,
        maxPrice: 620.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: now,
        iconAsset: 'cable',
      ),
      Price(
        id: 'battery',
        material: 'Batteries',
        categoryNameEn: 'Lithium & Lead Batteries',
        categoryNameHi: 'बैटरी',
        categoryNameMr: 'बॅटरी',
        minPrice: 70.0,
        maxPrice: 110.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: now,
        iconAsset: 'battery_charging_full',
      ),
      Price(
        id: 'display_monitor',
        material: 'Monitors & Displays',
        categoryNameEn: 'Monitors & Displays',
        categoryNameHi: 'मॉनिटर और स्क्रीन',
        categoryNameMr: 'मॉनिटर आणि स्क्रीन',
        minPrice: 100.0,
        maxPrice: 200.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: now,
        iconAsset: 'monitor',
      ),
      Price(
        id: 'mobile_phones',
        material: 'Mobile Phones',
        categoryNameEn: 'Smartphones & Feature Phones',
        categoryNameHi: 'मोबाइल फोन',
        categoryNameMr: 'मोबाईल फोन',
        minPrice: 500.0,
        maxPrice: 850.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Formal Recycler Benchmark',
        updatedAt: now,
        iconAsset: 'smartphone',
      ),
      Price(
        id: 'mixed_ewaste',
        material: 'Mixed E-Waste',
        categoryNameEn: 'Mixed E-Waste',
        categoryNameHi: 'मिश्रित ई-कचरा',
        categoryNameMr: 'मिश्रित ई-कचरा',
        minPrice: 50.0,
        maxPrice: 100.0,
        unit: 'kg',
        location: 'Nagpur',
        source: 'Informal Market Baseline',
        updatedAt: now,
        iconAsset: 'recycling',
      ),
    ];
  }

  Future<void> savePricesLocally(List<Price> prices) async {
    for (final price in prices) {
      await _dbService.insertPrice(price);
    }
  }

  (double, double) estimateLotValue({
    required String categoryId,
    required double weightKg,
    required String condition,
    required List<Price> prices,
  }) {
    return LotValuation.estimateRange(
      categoryId: categoryId,
      weightKg: weightKg,
      condition: condition,
      prices: prices,
    );
  }
}
