import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

/// Resolves which host the collector app should use for Node (`:5000`).
///
/// - Emulator: `http://10.0.2.2:5000`
/// - USB phone: `http://127.0.0.1:5000` after `adb reverse tcp:5000 tcp:5000`
/// - Same Wi‑Fi: LAN IP (`LAN_BACKEND_URL` or default below)
class BackendUrl {
  BackendUrl._();

  static String? _resolvedRoot;
  static String? lastError;

  static const String _override = String.fromEnvironment('BACKEND_URL');
  static const String _lan = String.fromEnvironment(
    'LAN_BACKEND_URL',
    defaultValue: 'http://10.1.106.69:5000',
  );

  static String _strip(String url) {
    if (url.endsWith('/')) return url.substring(0, url.length - 1);
    return url;
  }

  static List<String> get rootCandidates {
    final out = <String>[];
    void add(String raw) {
      if (raw.isEmpty) return;
      final v = _strip(raw);
      if (!out.contains(v)) out.add(v);
    }

    add(_override);
    add('http://127.0.0.1:5000');
    add('http://10.0.2.2:5000');
    add(_lan);
    return out;
  }

  static String get root => _resolvedRoot ?? rootCandidates.first;

  static String get api =>
      AppConstants.apiBaseUrlOverride.isNotEmpty
          ? _strip(AppConstants.apiBaseUrlOverride)
          : '$root/api';

  static bool get hasResolved => _resolvedRoot != null;

  static Future<String> resolve({http.Client? client, bool force = false}) async {
    if (!force && _resolvedRoot != null) return _resolvedRoot!;
    final httpClient = client ?? http.Client();
    lastError = null;

    for (final base in rootCandidates) {
      try {
        final res = await httpClient
            .get(Uri.parse('$base/health'))
            .timeout(const Duration(milliseconds: 1200));
        if (res.statusCode < 500) {
          _resolvedRoot = base;
          lastError = null;
          return base;
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    _resolvedRoot = null;
    return rootCandidates.first;
  }

  static void rememberRoot(String rootUrl) {
    _resolvedRoot = _strip(rootUrl);
  }

  static void resetForTesting() {
    _resolvedRoot = null;
    lastError = null;
  }
}
