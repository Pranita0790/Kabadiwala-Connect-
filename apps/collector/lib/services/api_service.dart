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
import '../models/pickup_request.dart';
import '../models/collector_rate.dart';
import 'session_store.dart';
import 'backend_url.dart';
import 'lot_valuation.dart' as lot_valuation;
import '../data/mpcb_recyclers_directory.dart';

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
      final list = MpcbRecyclersDirectory.getMatchedRecyclers(
        collectorLat: 18.6272,
        collectorLng: 73.8344,
        categoryId: categoryId,
      );
      return ApiResponse.success(list);
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

  final String? _baseUrlOverride;
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
  })  : _baseUrlOverride = baseUrl,
        _client = client ?? http.Client(),
        _sessionStore = sessionStore ?? SessionStore(),
        _authToken = authToken;

  String get baseUrl => _baseUrlOverride ?? BackendUrl.api;

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
      await BackendUrl.resolve(client: _client);
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
      'display_monitor': 'lcd_panel',
      'monitors_displays': 'lcd_panel',
      'motor': 'motor',
      'heavy_appliances': 'motor',
      'mixed': 'mixed_plastics',
      'mixed_plastics': 'mixed_plastics',
      'mixed_ewaste': 'mixed_plastics',
      'plastic': 'mixed_plastics',
      'paper': 'mixed_plastics',
      'book': 'mixed_plastics',
    };
    return aliases[key] ?? 'mixed_plastics';
  }

  static String mapCondition(String condition) {
    switch (condition.trim().toLowerCase()) {
      case 'good':
        return 'Good';
      case 'average':
      case 'partial':
      case 'partially_damaged':
        return 'Partial';
      default:
        return 'Scrap';
    }
  }

  Map<String, dynamic> lotToApiBody(EWasteLot lot) {
    final body = <String, dynamic>{
      'materialId': mapMaterialId(lot.categoryId),
      'categoryName': lot.categoryName,
      'condition': mapCondition(lot.condition),
      'weightKg': lot.weightKg,
      'syncStatus': 'PENDING_SYNC',
    };
    final notes = lot.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes.length > 2000 ? notes.substring(0, 2000) : notes;
    }
    final imagePath = lot.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      body['imagePath'] =
          imagePath.length > 500 ? imagePath.substring(0, 500) : imagePath;
    }
    // Backend expects a UUID clientReference for idempotent offline sync.
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(lot.id)) {
      body['clientReference'] = lot.id;
    }
    return body;
  }

  Future<void> _ensureAuthToken() async {
    if (_authToken != null && _authToken!.isNotEmpty) return;
    final stored = await _sessionStore.getAccessToken();
    if (stored != null && stored.isNotEmpty) {
      setAuthToken(stored);
    }
  }

  String _apiFailureMessage(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return 'Sign in required to sync. Use password login, not a local-only session.';
    }
    try {
      final body = json.decode(response.body);
      if (body is! Map) return '$fallback (${response.statusCode})';
      final details = body['details'];
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map) {
          final field = first['field'] ?? '';
          final message = first['message'] ?? fallback;
          return field.toString().isEmpty ? '$message' : '$field: $message';
        }
      }
      return (body['message'] as String?) ??
          (body['code'] as String?) ??
          '$fallback (${response.statusCode})';
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }
  }

  /// Password login against `POST /api/auth/login`.
  Future<ApiResponse<Map<String, dynamic>>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      await BackendUrl.resolve(client: _client);
      final uri = Uri.parse('$baseUrl/auth/login');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'identifier': identifier,
              'password': password,
              'app': 'collector',
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
      final code = body['code']?.toString();
      // Household USER accounts must use the customer app, not this collector login.
      if (response.statusCode == 403 || code == 'FORBIDDEN') {
        return ApiResponse.failure('wrongAppRoleError', statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        code ??
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
      await BackendUrl.resolve(client: _client);
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
      await BackendUrl.resolve(client: _client, force: true);
      await _ensureAuthToken();
      final uri = Uri.parse('$baseUrl/lots');
      final payload = json.encode(lotToApiBody(lot));
      final response = await _withAuthRetry(
        () => _client
            .post(
              uri,
              headers: _headers,
              body: payload,
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
      developer.log(
        'Lot upload failed: ${response.statusCode} ${response.body}',
        name: 'api.lots',
      );
      return ApiResponse.failure(
        _apiFailureMessage(response, 'Lot upload failed'),
        statusCode: response.statusCode,
      );
    } catch (e) {
      developer.log('Lot upload error', name: 'api.lots', error: e);
      return ApiResponse.failure(
        'Cannot reach backend at $baseUrl. Start Node on port 5000.',
      );
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
      await BackendUrl.resolve(client: _client, force: true);
      http.Response? response;
      Object? lastError;
      final paths = <String>['/rates', '/prices'];
      final roots = <String>{
        BackendUrl.root,
        ...BackendUrl.rootCandidates,
      };

      for (final root in roots) {
        for (final path in paths) {
          try {
            final uri = Uri.parse('$root/api$path');
            final candidate = await _client
                .get(uri, headers: _headers)
                .timeout(const Duration(seconds: 8));
            if (candidate.statusCode == 200) {
              BackendUrl.rememberRoot(root);
              response = candidate;
              break;
            }
            lastError = candidate.statusCode;
          } catch (e) {
            lastError = e;
          }
        }
        if (response != null) break;
      }

      if (response == null || response.statusCode != 200) {
        return ApiResponse.failure(
          'Price list unavailable',
          statusCode: response?.statusCode ?? 503,
        );
      }

      final body = json.decode(response.body);
      final prices = lot_valuation.LotValuation.pricesFromRatesResponse(body);
      if (prices.isEmpty) {
        developer.log(
          'Rates payload had no rows: ${response.body}',
          name: 'api.prices',
          error: lastError,
        );
        return ApiResponse.failure(
          'Price list unavailable',
          statusCode: 200,
        );
      }
      return ApiResponse.success(prices, statusCode: 200);
    } catch (e) {
      return ApiResponse.failure('Failed to fetch prices: $e');
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
      await BackendUrl.resolve(client: _client);
      final mapped = (categoryId != null && categoryId.isNotEmpty && categoryId != 'all')
          ? RemoteApiService.mapMaterialId(categoryId)
          : '';
      final query = mapped.isNotEmpty ? '?categoryId=$mapped' : '';
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
      await BackendUrl.resolve(client: _client, force: true);
      await _ensureAuthToken();
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
        'recyclerName': handover.recyclerName,
        'recycler_name': handover.recyclerName,
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
              // Collector may only stamp its own side. Recycler website
              // completes payment / dual confirm.
              body: json.encode({
                'completeBoth': false,
                'demoComplete': false,
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
      await BackendUrl.resolve(client: _client);
      await _ensureAuthToken();
      final uri = Uri.parse('$baseUrl/notifications');
      final response = await _withAuthRetry(
        () => _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8)),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final rawList = body['data']?['notifications'] ?? body['notifications'] ?? body['data'];
        if (rawList is List) {
          final notifs = rawList
              .whereType<Map>()
              .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item)))
              .where((item) => item.id.isNotEmpty)
              .toList();
          return ApiResponse.success(notifs, statusCode: 200);
        }
        return ApiResponse.success(const <AppNotification>[], statusCode: 200);
      }
      return ApiResponse.failure(
        'Notifications unavailable',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Failed to fetch notifications: $e');
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

  /// Public Razorpay Checkout Key Id (never the secret).
  Future<String?> fetchRazorpayKeyId() async {
    try {
      final uri = Uri.parse('$baseUrl/payment-config');
      final response =
          await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      final key = data['razorpayKeyId']?.toString();
      if (key == null || key.isEmpty) return null;
      return key;
    } catch (_) {
      return null;
    }
  }

  Future<ApiResponse<List<PickupRequest>>> fetchPickupRequests({String? status}) async {
    try {
      final query = (status != null && status.isNotEmpty) ? '?status=$status' : '';
      final uri = Uri.parse('$baseUrl/pickup-requests$query');
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return ApiResponse.failure('Pickup requests unavailable', statusCode: response.statusCode);
      }
      final decoded = json.decode(response.body);
      final list = _extractNamedList(decoded, 'requests');
      return ApiResponse.success(
        list.map((item) => PickupRequest.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      );
    } catch (e) {
      return ApiResponse.failure('Failed to fetch pickup requests: $e');
    }
  }

  Future<ApiResponse<PickupRequest>> patchPickupRequestStatus(String id, String status) async {
    try {
      final uri = Uri.parse('$baseUrl/pickup-requests/$id/status');
      final response = await _client
          .patch(uri, headers: _headers, body: json.encode({'status': status}))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final map = _extractNamedObject(decoded, 'request');
        if (map != null) {
          return ApiResponse.success(PickupRequest.fromMap(map));
        }
      }
      return ApiResponse.failure('Could not update pickup status', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.failure('Failed to update pickup status: $e');
    }
  }

  Future<ApiResponse<PickupRequest>> completePickupRequest({
    required String id,
    required double actualWeightKg,
    required String paymentMethod,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/pickup-requests/$id/complete');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: json.encode({
              'actualWeightKg': actualWeightKg,
              'paymentMethod': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final map = _extractNamedObject(decoded, 'request');
        if (map != null) {
          return ApiResponse.success(PickupRequest.fromMap(map));
        }
      }
      return ApiResponse.failure('Could not complete pickup', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.failure('Failed to complete pickup: $e');
    }
  }

  Future<ApiResponse<List<CollectorRate>>> fetchCollectorRates({
    String? collectorId,
  }) async {
    try {
      final query = (collectorId != null && collectorId.trim().isNotEmpty)
          ? '?collectorId=${Uri.encodeQueryComponent(collectorId.trim())}'
          : '';
      final uri = Uri.parse('$baseUrl/collector-rates$query');
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return ApiResponse.failure('Collector rates unavailable', statusCode: response.statusCode);
      }
      final decoded = json.decode(response.body);
      final list = _extractNamedList(decoded, 'rates');
      return ApiResponse.success(
        list.map((item) => CollectorRate.fromMap(Map<String, dynamic>.from(item as Map))).toList(),
      );
    } catch (e) {
      return ApiResponse.failure('Failed to fetch collector rates: $e');
    }
  }

  Future<ApiResponse<CollectorRate>> uploadCollectorRate(CollectorRate rate) async {
    try {
      final uri = Uri.parse('$baseUrl/collector-rates');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: json.encode({
              'id': rate.id,
              'collectorId': rate.collectorId,
              'materialCategory': rate.materialCategory,
              'materialName': rate.materialName,
              'ratePerKg': rate.ratePerKg,
              'unit': rate.unit,
              'isActive': rate.isActive,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(rate, statusCode: response.statusCode);
      }
      return ApiResponse.failure('Could not save collector rate', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.failure('Failed to save collector rate: $e');
    }
  }

  Future<ApiResponse<bool>> deleteRemoteCollectorRate(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/collector-rates/$id');
      final response = await _client.delete(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return ApiResponse.success(true);
      }
      return ApiResponse.failure('Could not delete collector rate', statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.failure('Failed to delete collector rate: $e');
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchLoyaltyCustomers() async {
    try {
      final uri = Uri.parse('$baseUrl/loyalty/customers');
      final response =
          await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return ApiResponse.failure(
          'Loyalty customers unavailable',
          statusCode: response.statusCode,
        );
      }
      final decoded = json.decode(response.body);
      final list = _extractNamedList(decoded, 'customers');
      return ApiResponse.success(
        list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } catch (e) {
      return ApiResponse.failure('Failed to fetch loyalty customers: $e');
    }
  }

  Future<ApiResponse<bool>> sendLoyaltyReminder({
    required String userId,
    required String cadence,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/loyalty/reminders');
      final response = await _client
          .post(
            uri,
            headers: _headers,
            body: json.encode({'userId': userId, 'cadence': cadence}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(true, statusCode: response.statusCode);
      }
      final body = json.decode(response.body);
      final message = body is Map
          ? (body['message']?.toString() ?? 'Could not send reminder')
          : 'Could not send reminder';
      return ApiResponse.failure(message, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse.failure('Failed to send reminder: $e');
    }
  }

  List<dynamic> _extractNamedList(dynamic decoded, String key) {
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is Map && data[key] is List) return data[key] as List;
      if (decoded[key] is List) return decoded[key] as List;
    }
    return const [];
  }

  Map<String, dynamic>? _extractNamedObject(dynamic decoded, String key) {
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is Map && data[key] is Map) {
        return Map<String, dynamic>.from(data[key] as Map);
      }
      if (decoded[key] is Map) {
        return Map<String, dynamic>.from(decoded[key] as Map);
      }
    }
    return null;
  }
}
