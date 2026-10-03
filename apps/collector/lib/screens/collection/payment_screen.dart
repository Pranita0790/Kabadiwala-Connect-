import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pickup_request.dart';
import '../../repositories/pickup_request_repository.dart';
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
  String _selectedPaymentMethod = 'CASH';
  bool _isProcessing = false;
  PickupRequest? _request;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    final req = await _repository.getRequestById(widget.requestId);
    setState(() => _request = req);
  }

  Future<void> _completePayment() async {
    setState(() => _isProcessing = true);
    try {
      final completed = await _repository.completeCollection(
        requestId: widget.requestId,
        actualWeightKg: widget.actualWeightKg,
        paymentMethod: _selectedPaymentMethod,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionCompletedScreen(request: completed),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failure: $e')),
        );
      }
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
                  Text('Processing Payment & Updating Ledger...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Payable Amount to Customer',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Weight: ${widget.actualWeightKg.toStringAsFixed(2)} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Select Payment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),

                  // Payment Options
                  _buildPaymentOption(
                    title: 'Cash',
                    subtitle: 'Direct cash handover to customer',
                    icon: Icons.payments_outlined,
                    value: 'CASH',
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentOption(
                    title: 'UPI Payment',
                    subtitle: 'GPay, PhonePe, Paytm QR or VPA',
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

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _completePayment,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark Paid & Complete Pickup'),
                    ),
                  ),
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
          backgroundColor: isSelected ? AppColors.primary : AppColors.backgroundSoft,
          child: Icon(icon, color: isSelected ? Colors.white : AppColors.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
