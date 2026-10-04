import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vendor.dart';
import '../models/sell_request.dart';
import 'session_store.dart';

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  const ApiResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResult.ok(T data, {int statusCode = 200}) =>
      ApiResult(success: true, data: data, statusCode: statusCode);

  factory ApiResult.fail(String message, {int? statusCode}) =>
      ApiResult(success: false, errorMessage: message, statusCode: statusCode);
}

/// Lightweight DTO so [ApiService] does not import loyalty_repository.
class LoyaltyNotificationDto {
  final String id;
  final String type;
  final String titleEn;
  final String bodyEn;
  final String? titleHi;
  final String? bodyHi;
  final String? collectorName;
  final String? createdAt;
  final bool isRead;

  const LoyaltyNotificationDto({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.bodyEn,
    this.titleHi,
    this.bodyHi,
    this.collectorName,
    this.createdAt,
    this.isRead = false,
  });

  factory LoyaltyNotificationDto.fromJson(Map<String, dynamic> json) {
    return LoyaltyNotificationDto(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      titleEn: json['titleEn']?.toString() ?? 'Notification',
      bodyEn: json['bodyEn']?.toString() ?? '',
      titleHi: json['titleHi']?.toString(),
      bodyHi: json['bodyHi']?.toString(),
      collectorName: json['collectorName']?.toString(),
      createdAt: json['createdAt']?.toString(),
      isRead: json['isRead'] == true,
    );
  }

  Map<String, dynamic> toLoyaltyJson() => {
        'id': id,
        'type': type,
        'titleEn': titleEn,
        'bodyEn': bodyEn,
        'titleHi': titleHi,
        'bodyHi': bodyHi,
        'collectorName': collectorName,
        'createdAt': createdAt,
        'isRead': isRead,
      };
}

/// Shared Node gateway client for the household user app.
/// Auth uses the same `/api/auth/*` endpoints as the collector app.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final SessionStore _sessionStore = SessionStore();
  final http.Client _client = http.Client();
  String? _authToken;

  /// Explicit override: `--dart-define=BACKEND_URL=http://10.1.121.107:5000`
  static const String _overrideRoot = String.fromEnvironment('BACKEND_URL');

  /// Laptop Wi‑Fi IP for physical phones on the same network.
  /// Override with `--dart-define=LAN_BACKEND_URL=http://YOUR_IP:5000` if IP changes.
  static const String _lanRoot = String.fromEnvironment(
    'LAN_BACKEND_URL',
    defaultValue: 'http://10.1.121.107:5000',
  );

  static const String _cloudRoot =
      'https://kabadiwala-backend-chd4.onrender.com';

  /// Last base that answered (kept for the process lifetime).
  static String? _activeApiBase;

  static List<String> get apiBaseUrls {
    final roots = <String>[
      if (_overrideRoot.trim().isNotEmpty) _overrideRoot.trim(),
      // Prefer LAN over Render for local phone testing — Render free tier often sleeps.
      if (_lanRoot.trim().isNotEmpty) _lanRoot.trim(),
      'http://10.0.2.2:5000',
      _cloudRoot,
      'http://127.0.0.1:5000',
    ];
    final bases = roots
        .map((r) => r.endsWith('/') ? '${r.substring(0, r.length - 1)}/api' : '$r/api')
        .toList();
    if (_activeApiBase != null) {
      bases.remove(_activeApiBase);
      bases.insert(0, _activeApiBase!);
    }
    return bases;
  }

  static Duration _timeoutFor(String base) {
    if (base.contains('onrender.com') || base.startsWith('https://')) {
      return const Duration(seconds: 45);
    }
    return const Duration(seconds: 5);
  }

  void setAuthToken(String? token) {
    _authToken = (token != null && token.isNotEmpty) ? token : null;
  }

  String? get authToken => _authToken;

  Future<void> restoreSession() async {
    final token = await _sessionStore.getAccessToken();
    setAuthToken(token);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<http.Response?> _tryGet(String path) async {
    for (final base in apiBaseUrls) {
      try {
        final response = await _client
            .get(Uri.parse('$base$path'), headers: _headers)
            .timeout(_timeoutFor(base));
        _activeApiBase = base;
        return response;
      } catch (_) {}
    }
    return null;
  }

  Future<http.Response?> _tryPost(String path, Map<String, dynamic> body) async {
    for (final base in apiBaseUrls) {
      try {
        final response = await _client
            .post(
              Uri.parse('$base$path'),
              headers: _headers,
              body: json.encode(body),
            )
            .timeout(_timeoutFor(base));
        _activeApiBase = base;
        return response;
      } catch (_) {}
    }
    return null;
  }

  /// Shared password login. [app] must be `user` for this client.
  Future<ApiResult<Map<String, dynamic>>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _tryPost('/auth/login', {
      'identifier': phone,
      'password': password,
      'app': 'user',
    });
    if (response == null) {
      return ApiResult.fail('Backend unreachable. Check laptop Wi‑Fi IP / server.');
    }
    final body = _decodeMap(response.body);
    if (response.statusCode == 200 && body['success'] == true) {
      final data = Map<String, dynamic>.from(body['data'] as Map? ?? {});
      final access = data['accessToken']?.toString() ?? '';
      final user = data['user'] as Map?;
      await _sessionStore.save(
        accessToken: access,
        refreshToken: data['refreshToken']?.toString(),
        userId: user?['id']?.toString(),
        fullName: user?['fullName']?.toString(),
        phone: user?['phone']?.toString(),
        role: user?['role']?.toString(),
      );
      setAuthToken(access);
      return ApiResult.ok(data);
    }
    return ApiResult.fail(
      body['message']?.toString() ??
          body['error']?.toString() ??
          'Login failed',
      statusCode: response.statusCode,
    );
  }

  /// Register a household USER on the shared auth API, then sign in.
  Future<ApiResult<Map<String, dynamic>>> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await _tryPost('/auth/register', {
      'fullName': fullName,
      'phone': phone,
      'password': password,
      'role': 'USER',
    });
    if (response == null) {
      return ApiResult.fail('Backend unreachable. Check laptop Wi‑Fi IP / server.');
    }
    final body = _decodeMap(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (body['success'] == true || body['data'] != null) {
        return login(phone: phone, password: password);
      }
    }
    return ApiResult.fail(
      body['message']?.toString() ??
          body['error']?.toString() ??
          'Registration failed',
      statusCode: response.statusCode,
    );
  }

  Future<ApiResult<Map<String, dynamic>>> fetchMe() async {
    final response = await _tryGet('/auth/me');
    if (response == null) return ApiResult.fail('Backend unreachable');
    final body = _decodeMap(response.body);
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'];
      if (data is Map) {
        return ApiResult.ok(Map<String, dynamic>.from(data));
      }
    }
    return ApiResult.fail('Session expired', statusCode: response.statusCode);
  }

  Future<void> logout() async {
    setAuthToken(null);
    await _sessionStore.clear();
  }

  Future<List<Vendor>> fetchNearbyVendors({String? category}) async {
    final query = (category != null && category.trim().isNotEmpty)
        ? '?category=${Uri.encodeQueryComponent(category.trim())}'
        : '';
    final response = await _tryGet('/user/vendors$query');
    if (response == null || response.statusCode != 200) return [];
    final body = _decodeMap(response.body);
    final list = body['data'] is Map ? (body['data'] as Map)['vendors'] : null;
    if (list is! List) return [];
    final vendors = list
        .map((item) => Vendor.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    vendors.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return vendors;
  }

  Future<SellRequest?> createPickupRequest({
    required String userName,
    required String userPhone,
    required String pickupAddress,
    required String materialCategory,
    required String materialName,
    required double estimatedWeightKg,
    required double ratePerKg,
    required String preferredTimeSlot,
    required String description,
    required String vendorId,
  }) async {
    final response = await _tryPost('/user/requests', {
      'userName': userName,
      'userPhone': userPhone,
      'pickupAddress': pickupAddress,
      'materialCategory': materialCategory,
      'materialName': materialName,
      'estimatedWeightKg': estimatedWeightKg,
      'ratePerKg': ratePerKg,
      'preferredTimeSlot': preferredTimeSlot,
      'description': description,
      'collectorId': vendorId,
    });
    if (response == null ||
        (response.statusCode != 200 && response.statusCode != 201)) {
      return null;
    }
    final body = _decodeMap(response.body);
    final data = body['data'] is Map ? (body['data'] as Map)['request'] : null;
    if (data is! Map) return null;
    return _sellRequestFromApiMap(
      Map<String, dynamic>.from(data),
      fallbackMaterialName: materialName,
      fallbackCategory: materialCategory,
      fallbackWeight: estimatedWeightKg,
      fallbackAddress: pickupAddress,
      fallbackTime: preferredTimeSlot,
      fallbackNote: description,
      fallbackVendorId: vendorId,
      fallbackRate: ratePerKg,
      fallbackUserName: userName,
      fallbackUserPhone: userPhone,
    );
  }

  /// Public Razorpay Key Id for Checkout (never returns the secret).
  Future<String?> fetchRazorpayKeyId() async {
    final response = await _tryGet('/user/payment-config');
    if (response == null || response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    final data = body['data'];
    if (data is! Map) return null;
    final key = data['razorpayKeyId']?.toString();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  Future<Map<String, dynamic>?> fetchLoyaltyMe() async {
    final response = await _tryGet('/loyalty/me');
    if (response == null || response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> postLoyaltyChoose(String collectorId) async {
    await _tryPost('/loyalty/chooses', {'collectorId': collectorId});
  }

  Future<Map<String, dynamic>?> postLoyaltyPurchase({
    required String collectorId,
    required String requestId,
    required double amount,
  }) async {
    final response = await _tryPost('/loyalty/purchases', {
      'collectorId': collectorId,
      'requestId': requestId,
      'amount': amount,
    });
    if (response == null ||
        (response.statusCode != 200 && response.statusCode != 201)) {
      return null;
    }
    final body = _decodeMap(response.body);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> fetchReferral() async {
    final response = await _tryGet('/loyalty/referral');
    if (response == null || response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<bool> applyReferralCode(String code) async {
    final response = await _tryPost('/loyalty/referral/apply', {
      'code': code.trim(),
    });
    return response != null &&
        (response.statusCode == 200 || response.statusCode == 201);
  }

  Future<List<LoyaltyNotificationDto>> fetchLoyaltyNotifications() async {
    final response = await _tryGet('/loyalty/notifications');
    if (response == null || response.statusCode != 200) return [];
    final body = _decodeMap(response.body);
    final list = body['data'] is Map
        ? (body['data'] as Map)['notifications']
        : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => LoyaltyNotificationDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Poll status after collector Accept / Reject in apps/collector.
  Future<SellRequest?> fetchPickupRequest(String requestId) async {
    if (requestId.isEmpty) return null;
    final response = await _tryGet('/user/requests/${Uri.encodeComponent(requestId)}');
    if (response == null || response.statusCode != 200) return null;
    final body = _decodeMap(response.body);
    final data = body['data'] is Map ? (body['data'] as Map)['request'] : null;
    if (data is! Map) return null;
    return _sellRequestFromApiMap(Map<String, dynamic>.from(data));
  }

  SellRequest _sellRequestFromApiMap(
    Map<String, dynamic> data, {
    String fallbackMaterialName = 'Scrap',
    String fallbackCategory = 'Other',
    double fallbackWeight = 0,
    String fallbackAddress = '',
    String fallbackTime = 'Flexible',
    String fallbackNote = '',
    String fallbackVendorId = '',
    double fallbackRate = 0,
    String fallbackUserName = '',
    String fallbackUserPhone = '',
  }) {
    final weight =
        (data['estimatedWeightKg'] as num?)?.toDouble() ?? fallbackWeight;
    return SellRequest(
      id: data['id']?.toString() ?? '',
      materialName: data['materialName']?.toString() ?? fallbackMaterialName,
      materialCategory:
          data['materialCategory']?.toString() ?? fallbackCategory,
      approximateQuantity: '${weight.toStringAsFixed(1)} kg',
      pickupLocation: data['pickupAddress']?.toString() ?? fallbackAddress,
      preferredTime:
          data['preferredTimeSlot']?.toString() ?? fallbackTime,
      note: data['description']?.toString() ?? fallbackNote,
      vendorId: data['collectorId']?.toString() ?? fallbackVendorId,
      ratePerKg: (data['ratePerKg'] as num?)?.toDouble() ?? fallbackRate,
      status: data['status']?.toString() ?? SellRequestStatus.created,
      actualWeightKg: (data['actualWeightKg'] as num?)?.toDouble(),
      finalAmount: (data['finalAmount'] as num?)?.toDouble(),
      userName: data['userName']?.toString() ?? fallbackUserName,
      userPhone: data['userPhone']?.toString() ?? fallbackUserPhone,
      pickupAddress: data['pickupAddress']?.toString() ?? fallbackAddress,
      preferredTimeSlot:
          data['preferredTimeSlot']?.toString() ?? fallbackTime,
      estimatedWeightKg: weight,
      description: data['description']?.toString() ?? fallbackNote,
      paymentStatus: data['paymentStatus']?.toString() ?? 'PENDING',
    );
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
