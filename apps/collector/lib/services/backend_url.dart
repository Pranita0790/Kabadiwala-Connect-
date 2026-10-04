import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'database_service.dart';

/// Resolves which host the collector app should use for Node (`:5000`).
///
/// Physical phone on Wi‑Fi → laptop LAN IP (`LAN_BACKEND_URL`).
/// USB debug → `127.0.0.1` only after `adb reverse tcp:5000 tcp:5000`.
/// Emulator → `10.0.2.2`.
class BackendUrl {
  BackendUrl._();

  static const _settingKey = 'backend_url';
  static String? _resolvedRoot;
  static String? _savedRoot;
  static String? lastError;

  static const String _override = String.fromEnvironment('BACKEND_URL');
  static const String _lan = String.fromEnvironment(
    'LAN_BACKEND_URL',
    defaultValue: 'http://10.1.121.20:5001',
  );

  static String _strip(String url) {
    var v = url.trim();
    if (v.endsWith('/')) v = v.substring(0, v.length - 1);
    if (v.isNotEmpty && !v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    return v;
  }

  static bool _isLoopback(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == '127.0.0.1' || host == 'localhost';
  }

  static List<String> get rootCandidates {
    final out = <String>[];
    void add(String raw) {
      if (raw.isEmpty) return;
      final v = _strip(raw);
      if (!out.contains(v)) out.add(v);
    }

    add(_override);
    if (_savedRoot != null && !_isLoopback(_savedRoot!)) {
      add(_savedRoot!);
    }
    add('http://127.0.0.1:5001');
    add('http://10.1.121.20:5001');
    add(_lan);
    add('http://10.0.2.2:5001');
    add('http://127.0.0.1:5000');
    add('http://10.1.121.20:5000');
    if (_savedRoot != null && _isLoopback(_savedRoot!)) {
      add(_savedRoot!);
    }
    return out;
  }

  static String get root => _resolvedRoot ?? rootCandidates.first;

  static String get api =>
      AppConstants.apiBaseUrlOverride.isNotEmpty
          ? _strip(AppConstants.apiBaseUrlOverride)
          : '$root/api';

  static bool get hasResolved => _resolvedRoot != null;

  static String get displayUrl => root;

  static Future<void> loadFromDatabase() async {
    try {
      final saved = await DatabaseService.instance.getSetting(_settingKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _savedRoot = _strip(saved);
        // Do not trust a saved URL until /health succeeds (old USB reverse
        // often left 127.0.0.1 stuck in SQLite).
      }
    } catch (_) {}
  }

  static Future<void> saveOverride(String url) async {
    final cleaned = _strip(url);
    _savedRoot = cleaned;
    _resolvedRoot = cleaned;
    lastError = null;
    await DatabaseService.instance.saveSetting(_settingKey, cleaned);
  }

  static Future<String> resolve({http.Client? client, bool force = false}) async {
    if (!force &&
        _resolvedRoot != null &&
        !_isLoopback(_resolvedRoot!)) {
      return _resolvedRoot!;
    }

    final httpClient = client ?? http.Client();
    lastError = null;

    for (final base in rootCandidates) {
      try {
        final res = await httpClient
            .get(Uri.parse('$base/health'))
            .timeout(const Duration(milliseconds: 2500));
        if (res.statusCode < 500) {
          _resolvedRoot = base;
          lastError = null;
          // Persist a working LAN URL so the next cold start is faster.
          if (!_isLoopback(base)) {
            try {
              await DatabaseService.instance.saveSetting(_settingKey, base);
              _savedRoot = base;
            } catch (_) {}
          }
          return base;
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    // Never stay stuck on a dead loopback from a previous session.
    if (_resolvedRoot != null && _isLoopback(_resolvedRoot!)) {
      _resolvedRoot = null;
    }
    return rootCandidates.first;
  }

  static void rememberRoot(String rootUrl) {
    final cleaned = _strip(rootUrl);
    // Avoid locking the app onto phone-local 127.0.0.1 without reverse.
    if (_isLoopback(cleaned) && _resolvedRoot != null && !_isLoopback(_resolvedRoot!)) {
      return;
    }
    _resolvedRoot = cleaned;
  }

  static void resetForTesting() {
    _resolvedRoot = null;
    _savedRoot = null;
    lastError = null;
  }
}
