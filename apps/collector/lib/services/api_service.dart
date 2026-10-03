import '../core/constants/app_constants.dart';
import 'backend_api_client.dart';
import '../models/app_notification.dart';
import '../models/e_waste_lot.dart';
import '../models/handover.dart';
import '../models/price.dart';
import '../models/price_alert.dart';
import '../models/recycler.dart';
import '../models/transaction.dart';

/// Generic response wrapper for backend operations.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {int statusCode = 200}) {
    return ApiResponse(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure(String message, {int? statusCode}) {
    return ApiResponse(
      success: false,
      errorMessage: message,
      statusCode: statusCode,
    );
  }
}

/// Abstract API service defining proposed network contracts.
///
/// ============================================================================
/// NOTE: The endpoints below are proposed contracts and are clearly marked as
/// PENDING BACKEND CONFIRMATION.
///
/// Proposed Endpoints:
/// 1. POST /api/lots                     -> Upload/create a new material lot
/// 2. POST /api/lots/{id}/sync           -> Sync an existing lot by client-side UUID
/// 3. GET  /api/prices                   -> Fetch latest market benchmark prices
/// 4. GET  /api/transactions/my          -> Fetch logged collector transactions
/// 5. GET  /api/recyclers                -> Fetch matching authorized recyclers (Member 3)
/// 6. POST /api/handovers                -> Create/upload handover record (Member 3)
/// 7. POST /api/handovers/{id}/confirm   -> Confirm handover on backend (Member 3)
/// 8. GET  /api/notifications            -> Fetch notification events (Member 3)
/// 9. POST /api/price-alerts             -> Register price alert (Member 3)
/// ============================================================================
abstract class ApiService {
  /// Proposed Contract: POST /api/lots
  /// Status: PENDING BACKEND CONFIRMATION
  Future<ApiResponse<EWasteLot>> uploadLot(EWasteLot lot);

  /// Proposed Contract: POST /api/lots/{id}/sync
  /// Status: PENDING BACKEND CONFIRMATION
  Future<ApiResponse<bool>> syncLotById(String id, Map<String, dynamic> lotData);

  /// Proposed Contract: GET /api/prices
  /// Status: PENDING BACKEND CONFIRMATION
  Future<ApiResponse<List<Price>>> fetchMarketPrices();

  /// Proposed Contract: GET /api/transactions/my
  /// Status: PENDING BACKEND CONFIRMATION
  Future<ApiResponse<List<Transaction>>> fetchMyTransactions();

  /// Proposed Contract: GET /api/recyclers
  /// Status: PENDING BACKEND CONFIRMATION (Member 3)
  Future<ApiResponse<List<Recycler>>> fetchMatchingRecyclers({String? categoryId});

  /// Proposed Contract: POST /api/handovers
  /// Status: PENDING BACKEND CONFIRMATION (Member 3)
  Future<ApiResponse<Handover>> uploadHandover(Handover handover);

  /// Proposed Contract: POST /api/handovers/{id}/confirm
  /// Status: PENDING BACKEND CONFIRMATION (Member 3)
  Future<ApiResponse<bool>> confirmHandoverOnBackend(String handoverId);

  /// Proposed Contract: GET /api/notifications
  /// Status: PENDING BACKEND CONFIRMATION (Member 3)
  Future<ApiResponse<List<AppNotification>>> fetchNotifications();

  /// Proposed Contract: POST /api/price-alerts
  /// Status: PENDING BACKEND CONFIRMATION (Member 3)
  Future<ApiResponse<PriceAlert>> uploadPriceAlert(PriceAlert alert);
}

/// Mock implementation of [ApiService] for testing and offline/sync simulation.
class MockApiService implements ApiService {
  bool shouldSucceed = true;
  Duration delay = Duration.zero;
  int uploadCallCount = 0;
  final List<EWasteLot> uploadedLots = [];

  @override
  Future<ApiResponse<EWasteLot>> uploadLot(EWasteLot lot) async {
    uploadCallCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      // Prevent duplicate storage in mock state
      uploadedLots.removeWhere((item) => item.id == lot.id);
      uploadedLots.add(lot);
      return ApiResponse.success(lot, statusCode: 201);
    } else {
      return ApiResponse.failure(
        'Simulated network or server error during lot upload',
        statusCode: 503,
      );
    }
  }

  @override
  Future<ApiResponse<bool>> syncLotById(String id, Map<String, dynamic> lotData) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      return ApiResponse.success(true, statusCode: 200);
    } else {
      return ApiResponse.failure('Simulated sync failed', statusCode: 500);
    }
  }

  @override
  Future<ApiResponse<List<Price>>> fetchMarketPrices() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      final now = DateTime.now();
      return ApiResponse.success([
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
      ]);
    } else {
      return ApiResponse.failure('Failed to fetch prices', statusCode: 500);
    }
  }

  @override
  Future<ApiResponse<List<Transaction>>> fetchMyTransactions() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      final now = DateTime.now();
      return ApiResponse.success([
        Transaction(
          id: 'tx_101',
          lotId: 'lot_pcb_01',
          recyclerId: 'EcoRecycle India (Nagpur)',
          quotedPrice: 3200.0,
          finalPrice: 3400.0,
          paymentStatus: 'PAID',
          handoverStatus: 'COMPLETED',
          createdAt: now.subtract(const Duration(hours: 4)),
          categoryName: 'Motherboard / PCB',
          weightKg: 12.5,
        ),
        Transaction(
          id: 'tx_102',
          lotId: 'lot_copper_02',
          recyclerId: 'Maharashtra Formal Dismantlers',
          quotedPrice: 4500.0,
          finalPrice: 4600.0,
          paymentStatus: 'PAID',
          handoverStatus: 'COMPLETED',
          createdAt: now.subtract(const Duration(days: 1)),
          categoryName: 'Copper Wire',
          weightKg: 8.0,
        ),
        Transaction(
          id: 'tx_103',
          lotId: 'lot_battery_03',
          recyclerId: 'GreenEarth Recyclers Ltd',
          quotedPrice: 2200.0,
          finalPrice: 2250.0,
          paymentStatus: 'PENDING',
          handoverStatus: 'COMPLETED',
          createdAt: now.subtract(const Duration(days: 3)),
          categoryName: 'Lithium Batteries',
          weightKg: 25.0,
        ),
        Transaction(
          id: 'tx_104',
          lotId: 'lot_display_04',
          recyclerId: 'Nagpur E-Waste Hub',
          quotedPrice: 2000.0,
          finalPrice: 2200.0,
          paymentStatus: 'PAID',
          handoverStatus: 'COMPLETED',
          createdAt: now.subtract(const Duration(days: 35)), // Previous month
          categoryName: 'Monitors & Displays',
          weightKg: 18.0,
        ),
      ]);
    } else {
      return ApiResponse.failure('Failed to fetch transactions', statusCode: 500);
    }
  }

  // ==========================================
  // MEMBER 3 OPERATIONS (MOCK IMPLEMENTATIONS)
  // ==========================================

  final List<Handover> uploadedHandovers = [];
  final List<PriceAlert> registeredPriceAlerts = [];

  @override
  Future<ApiResponse<List<Recycler>>> fetchMatchingRecyclers({String? categoryId}) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      final mockRecyclers = [
        const Recycler(
          id: 'rec_01',
          name: 'EcoRecycle Maharashtra',
          address: 'Plot 42, MIDC Hingna Industrial Area, Nagpur',
          acceptedCategories: ['pcb', 'copper_wire', 'battery', 'display', 'appliances', 'mixed'],
          distanceKm: 2.4,
          isAuthorized: true,
          rating: 4.8,
          contactPhone: '+91 98230 11223',
          latitude: 21.1458,
          longitude: 79.0882,
          indicativePrice: 320.0,
          unit: 'kg',
          isDemo: true,
        ),
        const Recycler(
          id: 'rec_02',
          name: 'GreenEarth Formal Dismantlers',
          address: 'Sector 8, Butibori Industrial Estate, Nagpur',
          acceptedCategories: ['pcb', 'copper_wire', 'display', 'mixed'],
          distanceKm: 4.8,
          isAuthorized: true,
          rating: 4.6,
          contactPhone: '+91 94221 44556',
          latitude: 21.1120,
          longitude: 79.0510,
          indicativePrice: 310.0,
          unit: 'kg',
          isDemo: true,
        ),
        const Recycler(
          id: 'rec_03',
          name: 'Central India Metal Refiners',
          address: 'Ghat Road, Cotton Market Yard, Nagpur',
          acceptedCategories: ['copper_wire', 'battery', 'appliances'],
          distanceKm: 7.2,
          isAuthorized: true,
          rating: 4.3,
          contactPhone: '+91 98900 77889',
          latitude: 21.1680,
          longitude: 79.1120,
          indicativePrice: 620.0,
          unit: 'kg',
          isDemo: true,
        ),
        const Recycler(
          id: 'rec_04',
          name: 'Vidarbha Safe E-Waste Center',
          address: 'Near Old Toll Plaza, Kamptee Road, Nagpur',
          acceptedCategories: ['pcb', 'battery', 'display'],
          distanceKm: 9.5,
          isAuthorized: false,
          rating: 4.0,
          contactPhone: '+91 97654 33221',
          latitude: 21.2010,
          longitude: 79.1350,
          indicativePrice: 280.0,
          unit: 'kg',
          isDemo: true,
        ),
      ];

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        final filtered = mockRecyclers.where((r) =>
            r.acceptedCategories.contains(categoryId) ||
            r.acceptedCategories.contains('mixed')).toList();
        return ApiResponse.success(filtered);
      }
      return ApiResponse.success(mockRecyclers);
    } else {
      return ApiResponse.failure('Failed to fetch recyclers', statusCode: 503);
    }
  }

  @override
  Future<ApiResponse<Handover>> uploadHandover(Handover handover) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      uploadedHandovers.removeWhere((h) => h.id == handover.id);
      uploadedHandovers.add(handover);
      return ApiResponse.success(handover, statusCode: 201);
    } else {
      return ApiResponse.failure(
        'Simulated network or server error during handover upload',
        statusCode: 503,
      );
    }
  }

  @override
  Future<ApiResponse<bool>> confirmHandoverOnBackend(String handoverId) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      return ApiResponse.success(true, statusCode: 200);
    } else {
      return ApiResponse.failure('Simulated confirmation failed', statusCode: 500);
    }
  }

  @override
  Future<ApiResponse<List<AppNotification>>> fetchNotifications() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      return ApiResponse.success([
        AppNotification(
          id: 'notif_demo_01',
          titleEn: '✓ Handover Confirmed',
          titleHi: '✓ माल हस्तांतरण निश्चित झाले',
          titleMr: '✓ माल हस्तांतरण निश्चित झाले',
          bodyEn: 'Your PCB lot has been successfully handed over to EcoRecycle Maharashtra.',
          bodyHi: 'आपका पीसीबी माल EcoRecycle Maharashtra को सफलतापूर्वक सौंपा गया।',
          bodyMr: 'तुमचा पीसीबी माल EcoRecycle Maharashtra ला यशस्वीरित्या हस्तांतरित झाला आहे.',
          type: AppConstants.notificationHandover,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          isDemo: true,
        ),
        AppNotification(
          id: 'notif_demo_02',
          titleEn: '🔔 Copper Price Alert',
          titleHi: '🔔 तांबे भाव इशारा',
          titleMr: '🔔 तांबे दर इशारा',
          bodyEn: 'Copper wire price reached ₹650/kg, matching your alert target.',
          bodyHi: 'तांबे का भाव ₹650/किलो पहुंच गया है।',
          bodyMr: 'तांब्याचा दर ₹650/किलो पोहोचला आहे, तुमच्या लक्ष्याशी जुळत आहे.',
          type: AppConstants.notificationPriceAlert,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
          isDemo: true,
        ),
      ]);
    } else {
      return ApiResponse.failure('Failed to fetch notifications', statusCode: 500);
    }
  }

  @override
  Future<ApiResponse<PriceAlert>> uploadPriceAlert(PriceAlert alert) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldSucceed) {
      registeredPriceAlerts.removeWhere((a) => a.id == alert.id);
      registeredPriceAlerts.add(alert);
      return ApiResponse.success(alert, statusCode: 201);
    } else {
      return ApiResponse.failure('Failed to create price alert', statusCode: 503);
    }
  }
}

/// Remote implementation of [ApiService] backed by the deployed Node.js API.
///
/// Connected endpoints:
///   - `POST /api/lots`            lot upload (offline sync)
///   - `POST /api/lots/sync`       idempotent lot sync by client reference
///   - `GET  /api/prices`          rate card (alias of `/api/rates`)
///
/// Endpoints the backend does not expose yet (recycler matching, handovers,
/// transactions, notifications, price alerts) keep the local mock so the UI
/// stays functional. Replace each `_mock` call once the endpoint lands.
///
/// Network failures on the connected endpoints are surfaced as failures (not
/// mock successes) so the sync queue retries them rather than marking a lot
/// synced when the server never saw it.
class RemoteApiService implements ApiService {
  final MockApiService _mock;
  final BackendApiClient _client;

  RemoteApiService({MockApiService? fallback, BackendApiClient? client})
      : _mock = fallback ?? MockApiService(),
        _client = client ?? BackendApiClient.instance;

  bool get _remoteEnabled => BackendApiClient.remoteEnabled;

  /// Maps the collector app's local category ids to backend material ids.
  /// Unknown ids are omitted so the lot is still accepted and valued later.
  static const Map<String, String> _materialIdByCategoryId = {
    'pcb_motherboard': 'pcb',
    'pcb': 'pcb',
    'copper_wire': 'cable',
    'cable': 'cable',
    'battery': 'battery',
    'display_monitor': 'lcd_panel',
    'lcd_panel': 'lcd_panel',
    'crt': 'crt',
    'heavy_appliances': 'motor',
    'motor': 'motor',
    'mixed_ewaste': 'mixed_plastics',
  };

  static String _conditionForBackend(String condition) {
    switch (condition.toLowerCase()) {
      case 'scrap':
        return 'Scrap';
      case 'partial':
        return 'Partial';
      case 'good':
      default:
        return 'Good';
    }
  }

  Map<String, dynamic> _lotToBackend(EWasteLot lot) {
    final materialId = _materialIdByCategoryId[lot.categoryId];
    return {
      // The local UUID is the server-side idempotency key.
      'clientReference': lot.id,
      if (materialId != null) 'materialId': materialId,
      if (lot.categoryName.isNotEmpty) 'categoryName': lot.categoryName,
      'condition': _conditionForBackend(lot.condition),
      'weightKg': lot.weightKg,
      if (lot.notes != null && lot.notes!.isNotEmpty) 'notes': lot.notes,
      if (lot.imagePath != null && lot.imagePath!.isNotEmpty)
        'imagePath': lot.imagePath,
      'syncStatus': AppConstants.syncSynced,
    };
  }

  @override
  Future<ApiResponse<EWasteLot>> uploadLot(EWasteLot lot) async {
    if (!_remoteEnabled) return _mock.uploadLot(lot);

    final result = await _client.post('/lots', body: _lotToBackend(lot));

    if (result.statusCode == 201 || result.statusCode == 200) {
      return ApiResponse.success(lot, statusCode: result.statusCode);
    }

    return ApiResponse.failure(
      result.message ?? 'Failed to upload lot',
      statusCode: result.statusCode,
    );
  }

  @override
  Future<ApiResponse<bool>> syncLotById(
    String id,
    Map<String, dynamic> lotData,
  ) async {
    if (!_remoteEnabled) return _mock.syncLotById(id, lotData);

    final result = await _client.post('/lots/sync', body: {
      'items': [
        {'clientReference': id, ...lotData},
      ],
    });

    if (result.success) {
      return ApiResponse.success(true, statusCode: result.statusCode);
    }

    return ApiResponse.failure(
      result.message ?? 'Failed to sync lot',
      statusCode: result.statusCode,
    );
  }

  @override
  Future<ApiResponse<List<Price>>> fetchMarketPrices() async {
    if (!_remoteEnabled) return _mock.fetchMarketPrices();

    // `/prices` is the collector alias of `/rates` on the current backend.
    var result = await _client.get('/prices');
    // Older deployments only expose `/rates`; fall back so the price board
    // still loads against them.
    if (!result.success && result.statusCode == 404) {
      result = await _client.get('/rates');
    }

    if (!result.success) {
      return ApiResponse.failure(
        result.message ?? 'Failed to fetch prices',
        statusCode: result.statusCode,
      );
    }

    final rawRates = _extractRates(result.body);
    if (rawRates == null) {
      return ApiResponse.failure(
        'Unexpected price response',
        statusCode: result.statusCode,
      );
    }

    final prices = rawRates
        .whereType<Map>()
        .map((rate) => _rateToPrice(rate.cast<String, dynamic>()))
        .toList();

    return ApiResponse.success(prices, statusCode: result.statusCode);
  }

  /// Accepts the new `{ success, rates[] }` envelope or a legacy bare array.
  List? _extractRates(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final direct = payload['rates'];
      if (direct is List) return direct;
      final nested = payload['data'];
      if (nested is Map && nested['rates'] is List) {
        return nested['rates'] as List;
      }
    }
    return null;
  }

  Price _rateToPrice(Map<String, dynamic> rate) {
    // New contract exposes `materialId`; legacy `/rates` uses `id`.
    final categoryKey =
        (rate['materialId'] ?? rate['id'] ?? rate['material'] ?? '') as String;
    final displayName =
        (rate['displayName'] ?? rate['material'] ?? categoryKey) as String;
    final ratePerKg = ((rate['ratePerKg'] ?? 0) as num).toDouble();
    final updatedAt =
        DateTime.tryParse((rate['updatedAt'] ?? '') as String) ?? DateTime.now();

    return Price(
      id: (rate['id'] ?? categoryKey) as String,
      material: displayName,
      minPrice: ratePerKg,
      maxPrice: ratePerKg,
      unit: (rate['unit'] as String?) ?? 'kg',
      location: (rate['region'] as String?) ?? 'IN-MH',
      source: (rate['source'] as String?) ?? 'Formal Recycler Rate',
      updatedAt: updatedAt,
      categoryId: categoryKey,
      categoryNameEn: displayName,
      categoryNameHi: displayName,
      categoryNameMr: displayName,
      iconAsset: 'recycling',
    );
  }

  // ---------------------------------------------------------------------------
  // Not yet exposed by the backend — keep the local mock.
  // ---------------------------------------------------------------------------

  @override
  Future<ApiResponse<List<Transaction>>> fetchMyTransactions() =>
      _mock.fetchMyTransactions();

  @override
  Future<ApiResponse<List<Recycler>>> fetchMatchingRecyclers({String? categoryId}) =>
      _mock.fetchMatchingRecyclers(categoryId: categoryId);

  @override
  Future<ApiResponse<Handover>> uploadHandover(Handover handover) =>
      _mock.uploadHandover(handover);

  @override
  Future<ApiResponse<bool>> confirmHandoverOnBackend(String handoverId) =>
      _mock.confirmHandoverOnBackend(handoverId);

  @override
  Future<ApiResponse<List<AppNotification>>> fetchNotifications() =>
      _mock.fetchNotifications();

  @override
  Future<ApiResponse<PriceAlert>> uploadPriceAlert(PriceAlert alert) =>
      _mock.uploadPriceAlert(alert);
}
