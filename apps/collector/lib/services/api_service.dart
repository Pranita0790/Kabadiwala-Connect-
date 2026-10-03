import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import '../models/e_waste_lot.dart';
import '../models/handover.dart';
import '../models/price.dart';
import '../models/price_alert.dart';
import '../models/recycler.dart';
import '../models/transaction.dart';
import 'session_store.dart';

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

  /// Check backend health status via /health/live.
  Future<bool> checkBackendHealth();
}

/// Mock implementation of [ApiService] for testing and offline/sync simulation.
class MockApiService implements ApiService {
  bool shouldSucceed = true;
  Duration delay = Duration.zero;
  int uploadCallCount = 0;
  final List<EWasteLot> uploadedLots = [];

  @override
  Future<bool> checkBackendHealth() async => true;

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

/// Remote implementation of [ApiService].
/// Connects to Node.js Express Backend. Lot/handover/transaction writes do not
/// fake-succeed via [MockApiService] — they fail so sync stays PENDING_SYNC.
class RemoteApiService implements ApiService {
  static RemoteApiService? _instance;

  final String baseUrl;
  final http.Client _client;
  final MockApiService _mock = MockApiService();
  final SessionStore _sessionStore;
  String? _authToken;
  Future<bool>? _refreshInFlight;

  RemoteApiService({
    String? baseUrl,
    http.Client? client,
    String? authToken,
    SessionStore? sessionStore,
  })  : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _client = client ?? http.Client(),
        _sessionStore = sessionStore ?? SessionStore(),
        _authToken = authToken;

  static RemoteApiService get instance {
    _instance ??= RemoteApiService();
    return _instance!;
  }

  static void setInstance(RemoteApiService service) {
    _instance = service;
  }

  void setAuthToken(String? token) {
    _authToken = (token != null && token.isNotEmpty) ? token : null;
  }

  String? get authToken => _authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

  /// Rotates the access token via `POST /api/auth/refresh`.
  Future<bool> refreshAccessToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _refreshAccessTokenOnce();
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _refreshAccessTokenOnce() async {
    try {
      final refresh = await _sessionStore.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        return false;
      }

      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        developer.log(
          'Token refresh failed: ${response.statusCode}',
          name: 'api.auth',
          error: response.body,
        );
        return false;
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map? ?? body);
      final access = data['accessToken'] as String?;
      final nextRefresh = data['refreshToken'] as String?;
      if (access == null || access.isEmpty) {
        return false;
      }

      setAuthToken(access);
      await _sessionStore.save(
        accessToken: access,
        refreshToken: nextRefresh,
      );
      return true;
    } catch (e) {
      developer.log('Token refresh error', name: 'api.auth', error: e);
      return false;
    }
  }

  /// Runs [send] and retries once after a refresh when the backend returns 401.
  Future<http.Response> _withAuthRetry(
    Future<http.Response> Function() send,
  ) async {
    var response = await send();
    if (response.statusCode != 401) {
      return response;
    }

    final refreshed = await refreshAccessToken();
    if (!refreshed) {
      return response;
    }

    return send();
  }

  /// Maps collector category ids onto backend `materials.id` values.
  static String mapMaterialId(String categoryId) {
    final key = categoryId.trim().toLowerCase();
    const aliases = {
      'pcb_motherboard': 'pcb',
      'motherboard': 'pcb',
      'motherboard_pcb': 'pcb',
      'pcb': 'pcb',
      'battery': 'battery',
      'batteries': 'battery',
      'lithium_batteries': 'battery',
      'cable': 'cable',
      'copper_wire': 'cable',
      'crt': 'crt',
      'lcd_panel': 'lcd_panel',
      'lcd': 'lcd_panel',
      'display': 'lcd_panel',
      'monitors_displays': 'lcd_panel',
      'motor': 'motor',
      'mixed': 'mixed_plastics',
      'mixed_plastics': 'mixed_plastics',
    };
    return aliases[key] ?? key;
  }

  static String mapCondition(String condition) {
    switch (condition.trim().toLowerCase()) {
      case 'good':
        return 'Good';
      case 'partial':
      case 'partially_damaged':
        return 'Partial';
      default:
        return 'Scrap';
    }
  }

  Map<String, dynamic> lotToApiBody(EWasteLot lot) {
    final materialId = mapMaterialId(lot.categoryId);
    final body = <String, dynamic>{
      'materialId': materialId,
      'categoryName': lot.categoryName,
      'condition': mapCondition(lot.condition),
      'weightKg': lot.weightKg,
      'syncStatus': 'PENDING_SYNC',
      'notes': lot.notes,
      'imagePath': lot.imagePath,
    };
    // Backend expects a UUID clientReference for idempotent offline sync.
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(lot.id)) {
      body['clientReference'] = lot.id;
    }
    return body;
  }

  /// Password login against `POST /api/auth/login`.
  Future<ApiResponse<Map<String, dynamic>>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'identifier': identifier,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final body = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final data = Map<String, dynamic>.from(body['data'] as Map? ?? body);
        final access = data['accessToken'] as String?;
        if (access != null) {
          setAuthToken(access);
        }
        return ApiResponse.success(data, statusCode: 200);
      }
      return ApiResponse.failure(
        (body['code'] as String?) ??
            (body['message'] as String?) ??
            'invalidCredentialsError',
        statusCode: response.statusCode,
      );
    } catch (e) {
      developer.log('Login request failed ($baseUrl/auth/login)', error: e, name: 'api.auth');
      return ApiResponse.failure('authBackendUnreachable');
    }
  }

  /// Collector registration against `POST /api/auth/register`.
  Future<ApiResponse<Map<String, dynamic>>> registerCollector({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'fullName': fullName,
              'phone': phone,
              'password': password,
              'role': 'COLLECTOR',
            }),
          )
          .timeout(const Duration(seconds: 12));

      final body = json.decode(response.body) as Map<String, dynamic>;
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return ApiResponse.success(
          Map<String, dynamic>.from(body['data'] as Map? ?? body),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        (body['code'] as String?) ??
            (body['message'] as String?) ??
            'registerFailed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      developer.log('Register request failed ($baseUrl/auth/register)', error: e, name: 'api.auth');
      return ApiResponse.failure('authBackendUnreachable');
    }
  }

  @override
  Future<bool> checkBackendHealth() async {
    try {
      final rootUrl = baseUrl.replaceAll('/api', '');
      final response = await _client
          .get(Uri.parse('$rootUrl/health/live'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ApiResponse<EWasteLot>> uploadLot(EWasteLot lot) async {
    try {
      final uri = Uri.parse('$baseUrl/lots');
      final response = await _withAuthRetry(
        () => _client
            .post(
              uri,
              headers: _headers,
              body: json.encode(lotToApiBody(lot)),
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        final data = body['data']?['lot'] ?? body['lot'] ?? body['data'];
        if (data != null || body['success'] == true) {
          return ApiResponse.success(lot, statusCode: response.statusCode);
        }
      }
      final body = json.decode(response.body);
      return ApiResponse.failure(
        (body['code'] as String?) ??
            (body['message'] as String?) ??
            'Lot upload failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Lot upload failed: $e');
    }
  }

  @override
  Future<ApiResponse<bool>> syncLotById(String id, Map<String, dynamic> lotData) async {
    try {
      final uri = Uri.parse('$baseUrl/lots/sync');
      final item = Map<String, dynamic>.from(lotData);
      if (!item.containsKey('clientReference')) {
        item['clientReference'] = id;
      }
      final response = await _withAuthRetry(
        () => _client
            .post(
              uri,
              headers: _headers,
              body: json.encode({
                'items': [item],
                'conflictStrategy': 'CLIENT_WINS',
              }),
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(true, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        'Lot sync failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Lot sync failed: $e');
    }
  }

  @override
  Future<ApiResponse<List<Price>>> fetchMarketPrices() async {
    try {
      final uri = Uri.parse('$baseUrl/prices');
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final rawList = body['data']?['rates'] ?? body['rates'] ?? body['data'];
        if (rawList is List && rawList.isNotEmpty) {
          final prices = rawList.map((item) {
            final rate = (item['ratePerKg'] as num?)?.toDouble() ?? 0.0;
            return Price(
              id: item['id']?.toString() ?? 'item_${item['materialId']}',
              material: item['materialName'] ?? item['categoryName'] ?? 'E-Waste',
              categoryNameEn: item['materialName'] ?? item['categoryName'] ?? 'E-Waste',
              categoryNameHi: item['categoryNameHi'] ?? item['materialName'] ?? 'ई-कचरा',
              categoryNameMr: item['categoryNameMr'] ?? item['materialName'] ?? 'ई-कचरा',
              minPrice: rate > 0 ? (rate * 0.9).roundToDouble() : 50.0,
              maxPrice: rate > 0 ? (rate * 1.1).roundToDouble() : 100.0,
              unit: item['unit'] ?? 'kg',
              location: item['region'] ?? 'Nagpur',
              source: item['source'] ?? 'Formal Benchmark',
              updatedAt: item['updatedAt'] != null ? DateTime.tryParse(item['updatedAt']) ?? DateTime.now() : DateTime.now(),
              iconAsset: 'recycling',
            );
          }).toList();
          return ApiResponse.success(prices, statusCode: 200);
        }
      }
      return await _mock.fetchMarketPrices();
    } catch (_) {
      return await _mock.fetchMarketPrices();
    }
  }

  @override
  Future<ApiResponse<List<Transaction>>> fetchMyTransactions() async {
    // Do not fall back to MockApiService demo rows (₹10,200 etc.).
    // That endpoint is not implemented on the backend yet; on failure the
    // repository must read real local SQLite transactions instead.
    try {
      final uri = Uri.parse('$baseUrl/transactions/my');
      final response = await _withAuthRetry(
        () => _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5)),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final rawList = body['data']?['transactions'] ?? body['transactions'] ?? body['data'];
        if (rawList is List) {
          final transactions = rawList
              .map((item) => Transaction.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
          return ApiResponse.success(transactions, statusCode: 200);
        }
        return ApiResponse.success(const <Transaction>[], statusCode: 200);
      }
      return ApiResponse.failure(
        'Transactions endpoint unavailable',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Failed to fetch transactions: $e');
    }
  }

  @override
  Future<ApiResponse<List<Recycler>>> fetchMatchingRecyclers({String? categoryId}) async {
    try {
      final query = (categoryId != null && categoryId.isNotEmpty && categoryId != 'all')
          ? '?categoryId=$categoryId'
          : '';
      final uri = Uri.parse('$baseUrl/recyclers$query');
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final rawList = body['data']?['recyclers'] ?? body['recyclers'] ?? body['data'];
        if (rawList is List && rawList.isNotEmpty) {
          final recyclers = rawList
              .map((item) => Recycler.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
          return ApiResponse.success(recyclers, statusCode: 200);
        }
      }
      return await _mock.fetchMatchingRecyclers(categoryId: categoryId);
    } catch (_) {
      return await _mock.fetchMatchingRecyclers(categoryId: categoryId);
    }
  }

  @override
  Future<ApiResponse<Handover>> uploadHandover(Handover handover) async {
    try {
      final uri = Uri.parse('$baseUrl/handovers');
      final body = {
        'id': handover.id,
        'clientReference': RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(handover.id)
            ? handover.id
            : null,
        'lotId': handover.lotId,
        'lot_id': handover.lotId,
        'recyclerId': handover.recyclerId,
        'materialCategory': handover.materialCategory,
        'weightKg': handover.weightKg,
        'agreedAmount': handover.agreedAmount,
        'qrPayload': handover.qrPayload,
      }..removeWhere((key, value) => value == null);

      final response = await _withAuthRetry(
        () => _client
            .post(
              uri,
              headers: _headers,
              body: json.encode(body),
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(handover, statusCode: response.statusCode);
      }
      final decoded = json.decode(response.body);
      return ApiResponse.failure(
        (decoded['code'] as String?) ??
            (decoded['message'] as String?) ??
            'Handover upload failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Handover upload failed: $e');
    }
  }

  @override
  Future<ApiResponse<bool>> confirmHandoverOnBackend(String handoverId) async {
    try {
      final uri = Uri.parse('$baseUrl/handovers/$handoverId/confirm');
      final response = await _withAuthRetry(
        () => _client
            .post(
              uri,
              headers: _headers,
              // Collector demo confirm stamps both parties so earnings post.
              body: json.encode({
                'completeBoth': true,
                'demoComplete': true,
              }),
            )
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(true, statusCode: 200);
      }
      return ApiResponse.failure(
        'Handover confirm failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Handover confirm failed: $e');
    }
  }

  @override
  Future<ApiResponse<List<AppNotification>>> fetchNotifications() async {
    try {
      final uri = Uri.parse('$baseUrl/notifications');
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final rawList = body['data']?['notifications'] ?? body['notifications'] ?? body['data'];
        if (rawList is List && rawList.isNotEmpty) {
          final notifs = rawList
              .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
          return ApiResponse.success(notifs, statusCode: 200);
        }
      }
      return await _mock.fetchNotifications();
    } catch (_) {
      return await _mock.fetchNotifications();
    }
  }

  @override
  Future<ApiResponse<PriceAlert>> uploadPriceAlert(PriceAlert alert) async {
    try {
      final uri = Uri.parse('$baseUrl/price-alerts');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: json.encode(alert.toMap()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(alert, statusCode: response.statusCode);
      }
      return await _mock.uploadPriceAlert(alert);
    } catch (_) {
      return await _mock.uploadPriceAlert(alert);
    }
  }
}
