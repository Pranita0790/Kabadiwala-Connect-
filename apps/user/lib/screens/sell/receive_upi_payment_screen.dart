import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/user_auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../models/payment_record.dart';
import '../../models/sell_draft.dart';
import '../../repositories/loyalty_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/user_profile_repository.dart';
import '../../repositories/vendor_repository.dart';
import 'vendor_review_screen.dart';

/// Household receives scrap payout via UPI (user does not pay).
///
/// Opens the phone UPI scanner apps and shows the customer's receive QR so the
/// kabadiwala can pay them. Creates/links the sell request to the collector.
class ReceiveUpiPaymentScreen extends StatefulWidget {
  final SellDraft draft;
  final String? existingRequestId;

  const ReceiveUpiPaymentScreen({
    super.key,
    required this.draft,
    this.existingRequestId,
  });

  @override
  State<ReceiveUpiPaymentScreen> createState() =>
      _ReceiveUpiPaymentScreenState();
}

class _ReceiveUpiPaymentScreenState extends State<ReceiveUpiPaymentScreen> {
  bool _busy = false;
  bool _linking = true;
  String? _requestId;
  String? _linkError;

  bool get _isPickup => widget.draft.mode == SellFulfillmentMode.pickup;

  String get _upiId {
    final phone = UserAuthController().userPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.length >= 10) {
      return '${phone.substring(phone.length - 10)}@upi';
    }
    return 'customer@upi';
  }

  String get _payeeName {
    final name = UserAuthController().userName.trim();
    if (name.isNotEmpty) return name;
    return UserProfileRepository().profile.name;
  }

  /// UPI QR for the kabadiwala to scan and pay this customer.
  String get _receiveUpiUri {
    final amount = widget.draft.estimatedAmount.toStringAsFixed(2);
    final tn = Uri.encodeComponent(
      'Scrap · ${widget.draft.materialsSummary}',
    );
    final pn = Uri.encodeComponent(_payeeName);
    return 'upi://pay?pa=$_upiId&pn=$pn&am=$amount&cu=INR&tn=$tn';
  }

  @override
  void initState() {
    super.initState();
    _linkCollectorThenOpenScanner();
  }

  Future<void> _linkCollectorThenOpenScanner() async {
    setState(() {
      _linking = true;
      _linkError = null;
    });

    try {
      final existingId = widget.existingRequestId;
      if (existingId != null && existingId.isNotEmpty) {
        _requestId = existingId;
      } else {
        final draft = widget.draft;
        final vendor = draft.vendor;
        VendorRepository().connectVendor(vendor.id);

        final request = await SellRequestRepository().createRequest(
          materialName: draft.primaryMaterialName,
          materialCategory: draft.primaryCategory,
          approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
          pickupLocation: draft.pickupAddress ?? vendor.address,
          preferredTime:
              draft.preferredTime ?? (_isPickup ? 'Flexible' : 'Shop visit'),
          note: [
            if (_isPickup) 'MODE:PICKUP' else 'MODE:SHOP_VISIT',
            'PAYOUT:UPI_RECEIVE',
            'Est. ₹${draft.estimatedAmount.toStringAsFixed(0)}',
            if (draft.note != null) draft.note!,
            'Items: ${draft.materialsSummary}',
          ].join(' | '),
          vendor: vendor,
        );
        _requestId = request.id;
      }

      if (!mounted) return;
      setState(() => _linking = false);

      // Directly open the phone's UPI scan apps — customer receives money.
      await _openUpiScanner();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _linking = false;
        _linkError = e.toString();
      });
    }
  }

  Future<void> _openUpiScanner() async {
    final candidates = <Uri>[
      Uri.parse('tez://upi/scan'),
      Uri.parse('gpay://upi/scan'),
      Uri.parse('phonepe://scan'),
      Uri.parse('paytmmp://cash_wallet'),
      Uri.parse('upi://scan'),
      // Fallback: open UPI pay intent with customer's VPA so apps open.
      Uri.parse(_receiveUpiUri),
    ];

    for (final uri in candidates) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // try next scheme
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'UPI app nahi khula. Neeche wala QR kabadiwala ko dikhayein — '
          'woh scan karke aapko paise bhejenge.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _markReceived() async {
    if (_busy) return;
    setState(() => _busy = true);

    final draft = widget.draft;
    final vendor = draft.vendor;
    VendorRepository().connectVendor(vendor.id);

    final referenceNo =
        'UPI-RECV-${DateTime.now().millisecondsSinceEpoch}';
    final requestId = _requestId;

    if (requestId != null && requestId.isNotEmpty) {
      SellRequestRepository().completeWithPayment(
        requestId: requestId,
        weightKg: draft.totalWeightKg,
        amount: draft.estimatedAmount,
      );
    } else {
      final request = await SellRequestRepository().createRequest(
        materialName: draft.primaryMaterialName,
        materialCategory: draft.primaryCategory,
        approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
        pickupLocation: draft.pickupAddress ?? vendor.address,
        preferredTime: draft.preferredTime ?? 'Shop visit',
        note: [
          if (_isPickup) 'MODE:PICKUP' else 'MODE:SHOP_VISIT',
          'REF:$referenceNo',
          'Items: ${draft.materialsSummary}',
        ].join(' | '),
        vendor: vendor,
      );
      SellRequestRepository().completeWithPayment(
        requestId: request.id,
        weightKg: draft.totalWeightKg,
        amount: draft.estimatedAmount,
      );
      _requestId = request.id;
    }

    final payment = PaymentRecord(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      amount: draft.estimatedAmount,
      date: DateTime.now(),
      materialName: draft.materialsSummary,
      weightKg: draft.totalWeightKg,
      status: 'PAID',
      referenceNo: referenceNo,
      vendorName: vendor.name,
    );
    PaymentRepository().addPayment(payment);

    final loyalty = await LoyaltyRepository().recordPurchase(
      collectorId: vendor.id,
      requestId: _requestId ?? payment.id,
      amount: draft.estimatedAmount,
    );
    if (loyalty?.isFavorite == true) {
      VendorRepository().connectVendor(vendor.id);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VendorReviewScreen(
          vendor: vendor,
          payment: payment,
          fulfillmentMode: draft.mode ?? SellFulfillmentMode.shopVisit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final amount = draft.estimatedAmount.toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Receive UPI payment')),
      body: _linking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_linkError != null)
                    Card(
                      color: const Color(0xFFFFE4E6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Collector link warning: $_linkError\n'
                          'Aap phir bhi UPI se paise receive kar sakte ho.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Text(
                            'Aapko paise milenge',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹$amount',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${draft.materialsSummary} · '
                            '${draft.totalWeightKg.toStringAsFixed(1)} kg',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kabadiwala: ${draft.vendor.name}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Apna UPI QR — kabadiwala scan karke pay kare',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: QrImageView(
                              data: _receiveUpiUri,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            _upiId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _upiId),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UPI ID copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy UPI ID'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _openUpiScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Open UPI scanner / app'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _markReceived,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : 'Maine payment receive kar liya',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(double.infinity, 54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aap payment nahi karte — kabadiwala aapko UPI se bhejta hai. '
                    'Request collector app se linked rehti hai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
