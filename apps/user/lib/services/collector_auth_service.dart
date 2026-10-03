import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'database_service.dart';

/// The backend session for a signed-in collector.
///
/// The app stores the backend's own access/refresh pair, not the Firebase ID
/// token. The Firebase token is a short-lived proof that a phone number was
/// verified once, exchanged at sign-in; it is never persisted, because
/// keeping two independent credentials on the device would double the blast
/// radius of a compromise for no benefit.
class CollectorSession {
  final String userId;
  final String accessToken;
  final String refreshToken;
  final String role;
  final bool needsProfile;

  const CollectorSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    this.needsProfile = false,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'role': role,
        'needsProfile': needsProfile,
      };

  static CollectorSession? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      return CollectorSession(
        userId: decoded['userId'] as String,
        accessToken: decoded['accessToken'] as String,
        refreshToken: decoded['refreshToken'] as String,
        role: decoded['role'] as String? ?? 'COLLECTOR',
        needsProfile: decoded['needsProfile'] as bool? ?? false,
      );
    } catch (error) {
      // A corrupt row must read as "signed out" rather than crash the app on
      // every launch, so it is dropped and re-authentication is required.
      developer.log(
        'Stored session was unreadable and has been discarded',
        name: 'collector.session',
        error: error,
      );

      return null;
    }
  }
}

/// Persists the backend session locally.
///
/// This is what lets a collector with no signal open the app and keep
/// working (AGENTS.md section 6). It is a convenience cache, not a
/// trust boundary: every request still carries the access token and the
/// backend still authorises it. A tampered local file buys nothing that a
/// stolen device has not already exposed.
class SessionStore {
  SessionStore({DatabaseService? db}) : _db = db ?? DatabaseService.instance;

  static const _key = 'backend_session';

  final DatabaseService _db;

  Future<CollectorSession?> read() async {
    final raw = await _db.getSetting(_key);

    return CollectorSession.fromJson(raw);
  }

  Future<void> write(CollectorSession session) async {
    await _db.saveSetting(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _db.deleteSetting(_key);
  }

  /// True when a usable session exists.
  ///
  /// Used for the offline-first path: a collector with a stored session goes
  /// straight into the app even with no connectivity.
  Future<bool> hasSession() async => (await read()) != null;
}

/// Result of exchanging a Firebase ID token for a backend session.
class SessionExchangeResult {
  final CollectorSession session;

  /// True when the backend created the account on this sign-in.
  final bool created;

  const SessionExchangeResult({required this.session, required this.created});
}

/// Raised when the backend rejects or cannot complete a session exchange.
class SessionExchangeException implements Exception {
  /// Backend error code, or `network` / `unexpected`.
  final String reason;

  /// Localisation key, never a literal string to show the collector.
  String get messageKey => switch (reason) {
        'network' => 'authErrorNetwork',
        'FIREBASE_NOT_CONFIGURED' => 'authErrorServerMisconfigured',
        'PHONE_NOT_SUPPORTED' => 'authErrorPhoneNotSupported',
        'FIREBASE_PROVIDER_NOT_ALLOWED' => 'authErrorPhoneOnly',
        'ACCOUNT_INACTIVE' => 'authErrorAccountInactive',
        'FIREBASE_TOKEN_INVALID' => 'authErrorSessionExpired',
        'DUPLICATE_RECORD' || 'PHONE_LINK_CONFLICT' => 'authErrorLinkConflict',
        'RATE_LIMITED' || 'TOO_MANY_REQUESTS' => 'authErrorTooManyAttempts',
        _ => 'authErrorUnknown',
      };

  const SessionExchangeException(this.reason);

  @override
  String toString() => 'SessionExchangeException($reason)';
}

/// Exchanges a verified Firebase ID token for a backend session.
///
/// This is the seam between the two halves of phone auth:
///
///   device                         backend
///   ------                         -------
///   Firebase sends/verifies SMS
///   device holds ID token  ---->    POST /api/auth/firebase/sign-in
///                                    verifies signature/aud/iss
///                                    resolves or creates the account
///                                  <----    access + refresh token
///
/// The backend is the only authority on identity, roles and account state.
/// Nothing here grants access on its own.
class CollectorAuthService {
  CollectorAuthService({
    required this.apiBaseUrl,
    required this.sessionStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// API root of the Node backend, including the `/api` prefix, with no
  /// trailing slash. Matches `AppConstants.apiBaseUrl`.
  final String apiBaseUrl;
  final SessionStore sessionStore;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  /// Trade [firebaseIdToken] for a backend session.
  ///
  /// [fullName] is only used when the backend has to create the account;
  /// Firebase Phone Auth carries no name. An existing account's name is
  /// never overwritten by a later sign-in.
  Future<SessionExchangeResult> exchangeFirebaseToken({
    required String firebaseIdToken,
    String? fullName,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/firebase/sign-in');

    final payload = <String, dynamic>{'idToken': firebaseIdToken};

    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['fullName'] = fullName.trim();
    }

    late http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } catch (error) {
      // Never log the body: it contains the Firebase ID token.
      developer.log(
        'Could not reach the backend to exchange a sign-in token',
        name: 'collector.auth',
        error: error,
      );

      throw const SessionExchangeException('network');
    }

    final Map<String, dynamic> decoded;

    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      developer.log(
        'Backend returned a non-JSON response to the sign-in exchange '
        '(status ${response.statusCode})',
        name: 'collector.auth',
        error: error,
      );

      throw const SessionExchangeException('unexpected');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final code = _errorCodeFrom(decoded) ?? _codeFromStatus(response.statusCode);

      throw SessionExchangeException(code);
    }

    final data = decoded['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw const SessionExchangeException('unexpected');
    }

    final user = data['user'] as Map<String, dynamic>?;

    if (user == null ||
        data['accessToken'] == null ||
        data['refreshToken'] == null) {
      throw const SessionExchangeException('unexpected');
    }

    final session = CollectorSession(
      userId: (user['publicId'] ?? user['id']).toString(),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      role: user['role'] as String? ?? 'COLLECTOR',
      needsProfile: data['needsProfile'] as bool? ?? false,
    );

    // Persist before returning: the collector must still be signed in after
    // an app kill, including a kill mid-sync.
    await sessionStore.write(session);

    return SessionExchangeResult(
      session: session,
      created: response.statusCode == 201,
    );
  }

  /// Revoke the backend session and clear local state.
  ///
  /// Local state is cleared even when the network call fails: a collector who
  /// taps "sign out" on a dead connection must still end up signed out on
  /// this device.
  Future<void> signOut() async {
    final session = await sessionStore.read();

    try {
      if (session != null) {
        await _client
            .post(
              Uri.parse('$apiBaseUrl/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({'refreshToken': session.refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (error) {
      developer.log(
        'Backend sign-out failed; clearing the local session anyway',
        name: 'collector.auth',
        error: error,
      );
    } finally {
      await sessionStore.clear();
    }
  }

  /// The backend's error code from a failure envelope, if it sent one.
  String? _errorCodeFrom(Map<String, dynamic> body) {
    final error = body['error'];

    if (error is Map<String, dynamic>) {
      final code = error['code'];

      if (code is String && code.isNotEmpty) return code;
    }

    final message = body['message'];

    if (message is Map<String, dynamic>) {
      final code = message['code'];

      if (code is String && code.isNotEmpty) return code;
    }

    return null;
  }

  /// Fall back to a coarse reason derived from the HTTP status.
  String _codeFromStatus(int status) => switch (status) {
        401 || 403 => 'FIREBASE_TOKEN_INVALID',
        409 => 'DUPLICATE_RECORD',
        429 => 'RATE_LIMITED',
        >= 500 => 'unexpected',
        _ => 'unexpected',
      };
}