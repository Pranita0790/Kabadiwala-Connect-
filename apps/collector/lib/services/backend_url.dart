import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'database_service.dart';

/// Resolves which host the collector app should use for Node.
///
/// Default: public Render URL (any network — no same-Wi‑Fi required).
/// Optional local debug: `--dart-define=BACKEND_URL=http://10.0.2.2:5000`
/// or Profile → Server URL.
class BackendUrl {
  BackendUrl._();

  static const _settingKey = 'backend_url';
  static String? _resolvedRoot;
  static String? _savedRoot;
  static String? lastError;

  /// Cloud API — keep in sync with docs/architecture/render-backend.md
  static const String productionRoot =
      'https://kabadiwala-backend-chd4.onrender.com';

  static const String _override = String.fromEnvironment('BACKEND_URL');
  static const String _lan = String.fromEnvironment('LAN_BACKEND_URL');

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

  static bool _isCloud(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.endsWith('onrender.com') || url.startsWith('https://');
  }

  static Duration _probeTimeout(String base) {
    // Render free tier cold-start can exceed 30s.
    if (_isCloud(base)) return const Duration(seconds: 55);
    return const Duration(seconds: 3);
  }

  static List<String> get rootCandidates {
    final out = <String>[];
    void add(String raw) {
      if (raw.isEmpty) return;
      final v = _strip(raw);
      if (!out.contains(v)) out.add(v);
    }

    // Explicit dart-define wins (local debug).
    add(_override);
    // Saved cloud URL from a previous successful probe.
    if (_savedRoot != null && _isCloud(_savedRoot!)) {
      add(_savedRoot!);
    }
    // Production default — no LAN / same-Wi‑Fi.
    add(productionRoot);
    // Optional LAN only when developer sets LAN_BACKEND_URL.
    add(_lan);
    // Local debug leftovers (last resort).
    add('http://10.0.2.2:5000');
    add('http://127.0.0.1:5000');
    if (_savedRoot != null && !_isCloud(_savedRoot!)) {
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

  /// Reset to cloud Render URL (clears stuck LAN / loopback prefs).
  static Future<void> useProductionCloud() async {
    await saveOverride(productionRoot);
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
            .get(Uri.parse('$base/health/live'))
            .timeout(_probeTimeout(base));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          _resolvedRoot = base;
          lastError = null;
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

    if (_resolvedRoot != null && _isLoopback(_resolvedRoot!)) {
      _resolvedRoot = null;
    }
    // Prefer cloud even if probe failed (cold start / offline); offline-first
    // sync will retry later.
    _resolvedRoot ??= productionRoot;
    return _resolvedRoot!;
  }

  static void rememberRoot(String rootUrl) {
    final cleaned = _strip(rootUrl);
    if (_isLoopback(cleaned) &&
        _resolvedRoot != null &&
        !_isLoopback(_resolvedRoot!)) {
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
