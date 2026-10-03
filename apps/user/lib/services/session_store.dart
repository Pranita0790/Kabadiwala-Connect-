import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the shared platform JWT session (same backend as collector).
class SessionStore {
  static const _fileName = 'user_auth_session.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> save({
    required String accessToken,
    String? refreshToken,
    String? userId,
    String? fullName,
    String? phone,
    String? role,
  }) async {
    final file = await _file();
    await file.writeAsString(
      json.encode({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
        'role': role,
      }),
    );
  }

  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = json.decode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final data = await read();
    final token = data?['accessToken']?.toString();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
