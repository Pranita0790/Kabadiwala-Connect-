import 'package:flutter/material.dart';
import '../../core/auth/user_auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../models/payment_record.dart';
import '../../models/sell_draft.dart';
import '../../repositories/loyalty_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/vendor_repository.dart';
import '../../services/razorpay_service.dart';
import 'request_status_screen.dart';
import 'vendor_review_screen.dart';

/// Pickup: send request to kabadiwala first.
/// Shop visit: Continue to payment → Razorpay Test checkout.
class SellDetailsScreen extends StatefulWidget {
  final SellDraft draft;

  const SellDetailsScreen({super.key, required this.draft});

  @override
  State<SellDetailsScreen> createState() => _SellDetailsScreenState();
}

class _SellDetailsScreenState extends State<SellDetailsScreen> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  final RazorpayService _razorpay = RazorpayService();
  String _timeSlot = 'Today, 4:00 PM - 6:00 PM';
  bool _busy = false;

  final _timeSlots = const [
    'Today, 4:00 PM - 6:00 PM',
    'Tomorrow, 10:00 AM - 12:00 PM',
    'Tomorrow, 2:00 PM - 4:00 PM',
    'Weekend, Morning Slot',
  ];

  bool get _isPickup => widget.draft.mode == SellFulfillmentMode.pickup;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(
      text: widget.draft.pickupAddress ?? 'B-402, Green Acres, Andheri East',
    );
    _noteCtrl = TextEditingController(text: widget.draft.note ?? '');
    _razorpay.init(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
    );
  }

  @override
  void dispose() {
    _razorpay.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  SellDraft _buildDraft() {
    return widget.draft.copyWith(
      pickupAddress: _isPickup
          ? _addressCtrl.text.trim()
          : widget.draft.vendor.address,
      preferredTime: _isPickup ? _timeSlot : 'Shop visit · anytime during hours',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
  }

  Future<void> _submitPickupRequest() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pickup address')),
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);

    final draft = _buildDraft();
    final vendor = draft.vendor;
    VendorRepository().connectVendor(vendor.id);

    final request = await SellRequestRepository().createRequest(
      materialName: draft.primaryMaterialName,
      materialCategory: draft.primaryCategory,
      approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
      pickupLocation: draft.pickupAddress!,
      preferredTime: draft.preferredTime!,
      note: [
        'MODE:PICKUP',
        'Est. ₹${draft.estimatedAmount.toStringAsFixed(0)}',
        'Items: ${draft.materialsSummary}',
        if (draft.note != null) draft.note!,
      ].join(' | '),
      vendor: vendor,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request sent to ${vendor.name}. Accept hone ke baad woh is address pe aayenge.',
        ),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RequestStatusScreen(request: request),
      ),
    );
  }

  Future<void> _goShopPayment() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final ready = await _razorpay.ensureConfigured();
      if (!ready) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Razorpay key not loaded. Set RAZORPAY_KEY_ID in repo .env, '
              'restart backend, then try again.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final draft = _buildDraft();
      final auth = UserAuthController();
      final opened = await _razorpay.openCheckout(
        amountRupees: draft.estimatedAmount,
        description:
            'Scrap · ${draft.materialsSummary} · ${draft.vendor.name}',
        contact: auth.userPhone.isNotEmpty ? auth.userPhone : null,
      );

      // Checkout sheet is on top — clear loading so UI is not stuck if
      // the user dismisses the sheet without a callback on some devices.
      if (opened && mounted) {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment open failed: $e')),
      );
    } finally {
      if (mounted && _busy) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _onRazorpaySuccess(String paymentId) async {
    await _completeShopPayment(paymentId);
  }

  /// Finishes shop-visit after Razorpay success or offline demo pay.
  Future<void> _completeShopPayment(String paymentId) async {
    setState(() => _busy = true);
    final draft = _buildDraft();
    final vendor = draft.vendor;
    VendorRepository().connectVendor(vendor.id);

    final request = await SellRequestRepository().createRequest(
      materialName: draft.primaryMaterialName,
      materialCategory: draft.primaryCategory,
      approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
      pickupLocation: draft.pickupAddress ?? vendor.address,
      preferredTime: draft.preferredTime ?? 'Shop visit',
      note: [
        'MODE:SHOP_VISIT',
        'RAZORPAY:$paymentId',
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
      referenceNo: paymentId,
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
          fulfillmentMode: draft.mode ?? SellFulfillmentMode.shopVisit,
        ),
      ),
    );
  }

  bool _isNetworkFailure(String message) {
    final m = message.toLowerCase();
    return m.contains('err_name_not_resolved') ||
        m.contains('webpage not available') ||
        m.contains('network') ||
        m.contains('dns') ||
        m.contains('internet') ||
        m.contains('timed out') ||
        m.contains('socket') ||
        m.contains('failed to connect') ||
        m.contains('host lookup');
  }

  void _onRazorpayFailure(String message) {
    if (!mounted) return;
    setState(() => _busy = false);

    // Phone often fails DNS for api.razorpay.com (no Wi‑Fi / bad DNS).
    if (_isNetworkFailure(message) || message.trim().isEmpty) {
      _showOfflinePayDialog(
        'Phone internet se Razorpay open nahi ho paya '
        '(api.razorpay.com — ERR_NAME_NOT_RESOLVED).\n\n'
        'Mobile Wi‑Fi / mobile data on karke dubara try karein, '
        'ya demo payment se flow continue karein.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showOfflinePayDialog(String body) async {
    final useDemo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Razorpay network issue'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retry later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Demo pay (offline)'),
          ),
        ],
      ),
    );

    if (useDemo == true && mounted) {
      await _completeShopPayment(
        'demo_offline_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendor = widget.draft.vendor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isPickup ? 'Pickup details' : 'Shop visit details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPickup
                          ? 'Kabadiwala ghar aayega'
                          : 'Aap dukan pe jayenge (Direct Cash)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vendor.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            vendor.address,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Est. payout ₹${widget.draft.estimatedAmount.toStringAsFixed(0)} · ${widget.draft.totalWeightKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isPickup) ...[
              const SizedBox(height: 12),
              Card(
                color: AppColors.primarySoft,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Iske baad request kabadiwala ko jayegi. Jab woh accept karega, tab woh aapke diye hue address pe ghar aayega.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_isPickup) ...[
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Your pickup address',
                  prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _timeSlot,
                decoration: const InputDecoration(
                  labelText: 'Preferred time',
                  prefixIcon: Icon(Icons.access_time, color: AppColors.primary),
                ),
                items: _timeSlots
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _timeSlot = v);
                },
              ),
              const SizedBox(height: 14),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shop hours: ${vendor.operatingHours}. '
                          'Razorpay needs phone internet (Wi‑Fi/data). '
                          'If you see Webpage not available / ERR_NAME_NOT_RESOLVED, '
                          'turn on data or use Demo pay below.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Gate code / call before arrival',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : (_isPickup ? _submitPickupRequest : _goShopPayment),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_isPickup ? Icons.send_rounded : Icons.payments_outlined),
              label: Text(
                _busy
                    ? (_isPickup ? 'Sending request…' : 'Opening Razorpay…')
                    : (_isPickup
                        ? 'Send pickup request'
                        : 'Continue to payment'),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            if (!_isPickup) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _completeShopPayment(
                          'demo_offline_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                icon: const Icon(Icons.wifi_off_rounded),
                label: const Text('Demo pay (if Razorpay page fails)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
