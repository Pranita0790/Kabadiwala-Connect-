/// Razorpay Test Mode (free sandbox — no real money).
///
/// Key Id can come from:
/// 1. Compile-time: `flutter run --dart-define-from-file=../../.env`
/// 2. Runtime: `GET /api/user/payment-config` (preferred — no rebuild)
///
/// Never put the Key Secret in the Flutter app.
class RazorpayConfig {
  RazorpayConfig._();

  static const String _compileTimeKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  /// Runtime override from backend (Key Id only).
  static String? _runtimeKeyId;

  static void setRuntimeKeyId(String? keyId) {
    final trimmed = keyId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _runtimeKeyId = null;
      return;
    }
    _runtimeKeyId = trimmed;
  }

  static String get keyId {
    final runtime = _runtimeKeyId;
    if (runtime != null && runtime.isNotEmpty) return runtime;
    return _compileTimeKeyId;
  }

  static bool get isConfigured =>
      keyId.startsWith('rzp_test_') || keyId.startsWith('rzp_live_');

  static bool get isTestMode => keyId.startsWith('rzp_test_');
}
