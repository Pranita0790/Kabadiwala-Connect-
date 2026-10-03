import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/razorpay_config.dart';
import '../../models/pickup_request.dart';
import '../../repositories/pickup_request_repository.dart';
import '../../services/razorpay_service.dart';
import 'collection_completed_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String requestId;
  final double actualWeightKg;
  final double finalAmount;

  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.actualWeightKg,
    required this.finalAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PickupRequestRepository _repository = PickupRequestRepository();
  final RazorpayService _razorpay = RazorpayService();
  String _selectedPaymentMethod = 'RAZORPAY';
  bool _isProcessing = false;
  PickupRequest? _request;

  @override
  void initState() {
    super.initState();
    _loadRequest();
    _razorpay.init(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
    );
    _razorpay.ensureConfigured();
  }

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    final req = await _repository.getRequestById(widget.requestId);
    if (mounted) setState(() => _request = req);
  }

  Future<void> _completePayment({String? razorpayPaymentId}) async {
    setState(() => _isProcessing = true);
    try {
      final method = razorpayPaymentId != null
          ? 'RAZORPAY'
          : _selectedPaymentMethod;
      final completed = await _repository.completeCollection(
        requestId: widget.requestId,
        actualWeightKg: widget.actualWeightKg,
        paymentMethod: method,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionCompletedScreen(request: completed),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failure: $e')),
      );
    }
  }

  Future<void> _payWithRazorpay() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final ready = await _razorpay.ensureConfigured();
      if (!ready) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Razorpay key not loaded. Set RAZORPAY_KEY_ID in .env and restart backend.',
            ),
          ),
        );
        return;
      }

      final customerPhone = _request?.userPhone;
      final opened = await _razorpay.openCheckout(
        amountRupees: widget.finalAmount,
        description:
            'Customer payout · ${_request?.userName ?? 'Customer'} · '
            '${widget.actualWeightKg.toStringAsFixed(1)} kg',
        contact: customerPhone,
      );

      if (opened && mounted) {
        // Checkout sheet is open — clear spinner so UI is not stuck.
        setState(() => _isProcessing = false);
      } else if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Razorpay open failed: $e')),
      );
    }
  }

  Future<void> _onRazorpaySuccess(String paymentId) async {
    await _completePayment(razorpayPaymentId: paymentId);
  }

  void _onRazorpayFailure(String message) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final m = message.toLowerCase();
    final networkFail = m.contains('err_name_not_resolved') ||
        m.contains('webpage not available') ||
        m.contains('network') ||
        m.contains('plugin not linked') ||
        m.contains('dns');

    if (networkFail) {
      _showOfflineDialog(message);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showOfflineDialog(String detail) async {
    final useDemo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Razorpay unavailable'),
        content: Text(
          '$detail\n\n'
          'Phone needs internet for api.razorpay.com.\n'
          'Or mark paid with demo / cash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark paid (demo)'),
          ),
        ],
      ),
    );
    if (useDemo == true && mounted) {
      await _completePayment(
        razorpayPaymentId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_selectedPaymentMethod == 'RAZORPAY') {
      await _payWithRazorpay();
    } else {
      await _completePayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: const Text('Payment & Settlement'),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Processing Payment…',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Payable Amount to Customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${widget.finalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Weight: ${widget.actualWeightKg.toStringAsFixed(2)} kg'
                              '${_request != null ? ' · ${_request!.userName}' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentOption(
                    title: 'Razorpay (UPI / Card)',
                    subtitle: RazorpayConfig.isConfigured
                        ? 'Test sandbox — opens Razorpay Checkout'
                        : 'Loads key from backend · needs phone internet',
                    icon: Icons.account_balance_wallet_outlined,
                    value: 'RAZORPAY',
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'Cash',
                    subtitle: 'Direct cash handover to customer',
                    icon: Icons.payments_outlined,
                    value: 'CASH',
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'UPI (manual)',
                    subtitle: 'GPay / PhonePe without Razorpay sheet',
                    icon: Icons.qr_code_scanner,
                    value: 'UPI',
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'Bank Transfer',
                    subtitle: 'IMPS / NEFT directly to account',
                    icon: Icons.account_balance_outlined,
                    value: 'BANK_TRANSFER',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onConfirmPressed,
                      icon: Icon(
                        _selectedPaymentMethod == 'RAZORPAY'
                            ? Icons.payment
                            : Icons.check_circle,
                      ),
                      label: Text(
                        _selectedPaymentMethod == 'RAZORPAY'
                            ? 'Pay with Razorpay'
                            : 'Mark Paid & Complete Pickup',
                      ),
                    ),
                  ),
                  if (_selectedPaymentMethod == 'RAZORPAY') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _completePayment(
                          razorpayPaymentId:
                              'demo_${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        icon: const Icon(Icons.wifi_off_rounded),
                        label: const Text('Demo pay (if Razorpay page fails)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return Card(
      color: isSelected ? Colors.white : AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              isSelected ? AppColors.primary : AppColors.backgroundSoft,
          child: Icon(
            icon,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        trailing: Radio<String>(
          value: value,
          groupValue: _selectedPaymentMethod,
          activeColor: AppColors.primary,
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPaymentMethod = val);
            }
          },
        ),
        onTap: () {
          setState(() => _selectedPaymentMethod = value);
        },
      ),
    );
  }
}
