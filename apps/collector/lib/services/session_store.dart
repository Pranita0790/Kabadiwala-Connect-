import 'database_service.dart';

/// Persists the platform JWT session issued by the Node backend.
class SessionStore {
  static const _accessKey = 'backend_access_token';
  static const _refreshKey = 'backend_refresh_token';
  static const _userIdKey = 'backend_user_id';

  final DatabaseService _db;

  SessionStore({DatabaseService? dbService})
      : _db = dbService ?? DatabaseService.instance;

  Future<void> save({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    await _db.saveSetting(_accessKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _db.saveSetting(_refreshKey, refreshToken);
    }
    if (userId != null && userId.isNotEmpty) {
      await _db.saveSetting(_userIdKey, userId);
    }
  }

  Future<String?> getAccessToken() => _db.getSetting(_accessKey);

  Future<String?> getRefreshToken() => _db.getSetting(_refreshKey);

  Future<String?> getBackendUserId() => _db.getSetting(_userIdKey);

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    await _db.saveSetting(_accessKey, '');
    await _db.saveSetting(_refreshKey, '');
    await _db.saveSetting(_userIdKey, '');
  }
}
