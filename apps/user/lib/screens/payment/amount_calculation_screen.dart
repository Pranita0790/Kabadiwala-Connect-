import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/sell_request_repository.dart';

import '../../models/sell_request.dart';

class AmountCalculationScreen extends StatelessWidget {
  final String? requestId;
  final SellRequest? request;

  const AmountCalculationScreen({super.key, this.requestId, this.request});

  @override
  Widget build(BuildContext context) {
    final repo = SellRequestRepository();
    final req = request ?? repo.getRequestById(requestId ?? '') ?? repo.activeRequest;

    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Amount Calculation')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final double weight = req.actualWeightKg ?? 18.4;
    final double rate = req.ratePerKg;
    final double total = req.finalAmount ?? (weight * rate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Amount Calculation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Calculation Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Divider(height: 24),
                    _buildRow('Material Category', req.materialCategory),
                    _buildRow('Material Type', req.materialName),
                    _buildRow('Actual Scale Weight', '${weight.toStringAsFixed(1)} kg'),
                    _buildRow('Vendor Agreed Rate', '₹${rate.toStringAsFixed(0)} / kg'),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable Amount',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  repo.advanceRequestStatus(req.id);
                  Navigator.pushReplacementNamed(context, '/payment-result', arguments: req.id);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('View Payment Receipt & Summary'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        ],
      ),
    );
  }
}
