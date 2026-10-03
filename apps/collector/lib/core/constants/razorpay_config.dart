/// Razorpay Test Mode for collector customer payouts (sandbox).
///
/// Key Id from:
/// 1. `flutter run --dart-define-from-file=../../.env`
/// 2. Runtime `GET /api/payment-config` (preferred)
///
/// Never put RAZORPAY_KEY_SECRET in the Flutter app.
class RazorpayConfig {
  RazorpayConfig._();

  static const String _compileTimeKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

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
