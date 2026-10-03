import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../core/constants/razorpay_config.dart';
import 'api_service.dart';

typedef RazorpaySuccess = void Function(String paymentId);
typedef RazorpayFailure = void Function(String message);

/// Razorpay Checkout wrapper for collector → customer settlement.
class RazorpayService {
  Razorpay? _razorpay;
  RazorpaySuccess? _onSuccess;
  RazorpayFailure? _onFailure;

  bool get isReady => RazorpayConfig.isConfigured;

  Future<bool> ensureConfigured() async {
    if (RazorpayConfig.isConfigured) return true;
    final key = await RemoteApiService.instance.fetchRazorpayKeyId();
    RazorpayConfig.setRuntimeKeyId(key);
    return RazorpayConfig.isConfigured;
  }

  void init({
    required RazorpaySuccess onSuccess,
    required RazorpayFailure onFailure,
  }) {
    dispose();
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    try {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } catch (e) {
      debugPrint('Razorpay init failed: $e');
    }
  }

  Future<bool> openCheckout({
    required double amountRupees,
    required String description,
    String? contact,
    String name = 'Kabadiwala Connect',
  }) async {
    if (!RazorpayConfig.isConfigured) {
      _onFailure?.call(
        'Razorpay key missing. Set RAZORPAY_KEY_ID in repo .env and restart backend.',
      );
      return false;
    }
    if (_razorpay == null) {
      _onFailure?.call(
        'Razorpay plugin not ready. Fully stop app, then flutter run '
        '(hot restart is not enough after adding the plugin).',
      );
      return false;
    }

    final paise = (amountRupees * 100).round();
    if (paise < 100) {
      _onFailure?.call('Amount too small for Razorpay (min ₹1).');
      return false;
    }

    final shortDesc = description.length > 80
        ? '${description.substring(0, 77)}...'
        : description;

    final options = <String, dynamic>{
      'key': RazorpayConfig.keyId,
      'amount': paise,
      'currency': 'INR',
      'name': name,
      'description': shortDesc,
      'timeout': 180,
      'prefill': <String, dynamic>{
        if (contact != null && contact.trim().isNotEmpty)
          'contact': _normalizePhone(contact),
      },
      'theme': <String, dynamic>{'color': '#134233'},
    };

    try {
      await const MethodChannel('razorpay_flutter').invokeMethod('resync');
    } on MissingPluginException {
      _onFailure?.call(
        'Razorpay plugin not linked. Stop app, then:\n'
        'flutter clean && flutter pub get && flutter run',
      );
      return false;
    } catch (_) {}

    try {
      _razorpay!.open(options);
      return true;
    } catch (e) {
      debugPrint('Razorpay open failed: $e');
      if (e is MissingPluginException) {
        _onFailure?.call(
          'Razorpay plugin not linked. Stop app, then flutter clean && flutter run',
        );
      } else {
        _onFailure?.call('Could not open Razorpay: $e');
      }
      return false;
    }
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    final id = response.paymentId?.trim();
    if (id == null || id.isEmpty) {
      _onFailure?.call('Payment succeeded but no payment id returned.');
      return;
    }
    _onSuccess?.call(id);
  }

  void _handleError(PaymentFailureResponse response) {
    final message = response.message?.trim();
    _onFailure?.call(
      message != null && message.isNotEmpty
          ? message
          : 'Payment cancelled / failed (code ${response.code})',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay external wallet: ${response.walletName}');
  }

  void dispose() {
    try {
      _razorpay?.clear();
    } catch (_) {}
    _razorpay = null;
    _onSuccess = null;
    _onFailure = null;
  }
}
