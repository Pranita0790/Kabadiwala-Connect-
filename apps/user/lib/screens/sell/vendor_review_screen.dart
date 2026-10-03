import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/payment_record.dart';
import '../../models/sell_draft.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';

/// Final step: rate / review the kabadiwala after payment.
class VendorReviewScreen extends StatefulWidget {
  final Vendor vendor;
  final PaymentRecord payment;
  final SellFulfillmentMode fulfillmentMode;

  const VendorReviewScreen({
    super.key,
    required this.vendor,
    required this.payment,
    required this.fulfillmentMode,
  });

  @override
  State<VendorReviewScreen> createState() => _VendorReviewScreenState();
}

class _VendorReviewScreenState extends State<VendorReviewScreen> {
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    VendorRepository().connectVendor(widget.vendor.id);
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thanks! ${_stars}★ review saved for ${widget.vendor.name}'),
      ),
    );
  }

  void _done() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = widget.vendor;
    final payment = widget.payment;
    final modeLabel = widget.fulfillmentMode == SellFulfillmentMode.pickup
        ? 'Home Pickup'
        : 'Direct Cash (Shop)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction complete'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              'Payment successful',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '₹${payment.amount.toStringAsFixed(0)} · ${payment.weightKg.toStringAsFixed(1)} kg · $modeLabel',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Txn ${payment.referenceNo}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _submitted ? 'Review submitted' : 'Rate your kabadiwala',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vendor.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (!_submitted) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return IconButton(
                            onPressed: () => setState(() => _stars = star),
                            icon: Icon(
                              star <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: AppColors.accent,
                              size: 36,
                            ),
                          );
                        }),
                      ),
                      TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Write a review (optional)',
                          hintText: 'Punctual, fair weighing, polite…',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Submit review'),
                      ),
                      TextButton(
                        onPressed: _done,
                        child: const Text('Skip for now'),
                      ),
                    ] else ...[
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      if (_commentCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _commentCtrl.text.trim(),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _done,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Back to home'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
