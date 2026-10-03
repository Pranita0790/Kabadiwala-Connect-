import 'package:flutter/material.dart';
import '../../core/auth/user_auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/razorpay_config.dart';
import '../../models/payment_record.dart';
import '../../models/sell_draft.dart';
import '../../repositories/loyalty_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/vendor_repository.dart';
import '../../services/razorpay_service.dart';
import 'vendor_review_screen.dart';

/// Confirm transaction — UPI opens Razorpay Test checkout.
class SellPaymentScreen extends StatefulWidget {
  final SellDraft draft;

  const SellPaymentScreen({super.key, required this.draft});

  @override
  State<SellPaymentScreen> createState() => _SellPaymentScreenState();
}

class _SellPaymentScreenState extends State<SellPaymentScreen> {
  final RazorpayService _razorpay = RazorpayService();
  String _payMethod = 'UPI';
  bool _busy = false;

  bool get _isPickup => widget.draft.mode == SellFulfillmentMode.pickup;

  @override
  void initState() {
    super.initState();
    _razorpay.init(
      onSuccess: (paymentId) => _finalize(referenceNo: paymentId),
      onFailure: (message) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;

    if (_payMethod == 'UPI') {
      if (!RazorpayConfig.isConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add RAZORPAY_KEY_ID=rzp_test_... in .env, then rebuild with '
              '--dart-define-from-file=../../.env',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      setState(() => _busy = true);
      final draft = widget.draft;
      final auth = UserAuthController();
      _razorpay.openCheckout(
        amountRupees: draft.estimatedAmount,
        description:
            'Scrap · ${draft.materialsSummary} · ${draft.vendor.name}',
        contact: auth.userPhone.isNotEmpty ? auth.userPhone : null,
      );
      return;
    }

    await _finalize(referenceNo: 'CASH-${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> _finalize({required String referenceNo}) async {
    if (!mounted) return;
    setState(() => _busy = true);

    final draft = widget.draft;
    final vendor = draft.vendor;
    VendorRepository().connectVendor(vendor.id);

    final request = await SellRequestRepository().createRequest(
      materialName: draft.primaryMaterialName,
      materialCategory: draft.primaryCategory,
      approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
      pickupLocation: draft.pickupAddress ?? vendor.address,
      preferredTime: draft.preferredTime ?? (_isPickup ? 'Flexible' : 'Shop visit'),
      note: [
        if (draft.mode == SellFulfillmentMode.pickup) 'MODE:PICKUP' else 'MODE:SHOP_VISIT',
        'REF:$referenceNo',
        if (draft.note != null) draft.note!,
        'Items: ${draft.materialsSummary}',
      ].join(' | '),
      vendor: vendor,
    );

    final amount = draft.estimatedAmount;
    final payment = PaymentRecord(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      date: DateTime.now(),
      materialName: draft.materialsSummary,
      weightKg: draft.totalWeightKg,
      status: 'PAID',
      referenceNo: referenceNo,
      vendorName: vendor.name,
    );
    PaymentRepository().addPayment(payment);
    SellRequestRepository().completeWithPayment(
      requestId: request.id,
      weightKg: draft.totalWeightKg,
      amount: amount,
    );
    final loyalty = await LoyaltyRepository().recordPurchase(
      collectorId: vendor.id,
      requestId: request.id.isNotEmpty ? request.id : payment.id,
      amount: amount,
    );
    if (loyalty?.isFavorite == true) {
      VendorRepository().connectVendor(vendor.id);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (loyalty?.isFavorite == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${vendor.name} is now your Favorite Kabadiwala'),
        ),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VendorReviewScreen(
          vendor: vendor,
          payment: payment,
          fulfillmentMode: draft.mode ?? SellFulfillmentMode.pickup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final vendor = draft.vendor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Confirm payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const Divider(height: 22),
                    _row('Kabadiwala', vendor.name),
                    _row(
                      'Mode',
                      _isPickup ? 'Home Pickup' : 'Direct Cash (Shop)',
                    ),
                    _row('Materials', draft.materialsSummary),
                    _row('Total weight', '${draft.totalWeightKg.toStringAsFixed(1)} kg'),
                    _row(
                      _isPickup ? 'Pickup address' : 'Shop address',
                      draft.pickupAddress ?? vendor.address,
                    ),
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You receive',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          '₹${draft.estimatedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      RazorpayConfig.isTestMode
                          ? 'Razorpay Test Mode — no real money charged'
                          : 'Payout based on entered weight × rate/kg',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Receive payment via',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('UPI / Razorpay'),
                  selected: _payMethod == 'UPI',
                  onSelected: (_) => setState(() => _payMethod = 'UPI'),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _payMethod == 'UPI' ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _payMethod == 'Cash',
                  onSelected: (_) => setState(() => _payMethod = 'Cash'),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _payMethod == 'Cash' ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _busy ? null : _confirm,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      _payMethod == 'UPI'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.check_circle_outline,
                    ),
              label: Text(
                _busy
                    ? 'Opening Razorpay…'
                    : (_payMethod == 'UPI'
                        ? 'Pay with Razorpay'
                        : 'Complete cash transaction'),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
