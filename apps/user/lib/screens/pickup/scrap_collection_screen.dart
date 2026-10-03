import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/sell_request_repository.dart';

import '../../models/sell_request.dart';

class ScrapCollectionScreen extends StatelessWidget {
  final String? requestId;
  final SellRequest? request;

  const ScrapCollectionScreen({super.key, this.requestId, this.request});

  @override
  Widget build(BuildContext context) {
    final repo = SellRequestRepository();
    final req = request ?? repo.getRequestById(requestId ?? '') ?? repo.activeRequest;

    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scrap Collection')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final double actualWeight = req.actualWeightKg ?? 18.4;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scrap Collection & Weighing'),
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
                  children: [
                    const Icon(Icons.scale_rounded, size: 56, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Weight Recorded by Vendor Scale',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vendor: ${req.vendorName}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24),

                    // Clear distinction between Approximate vs Actual
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Approximate Customer Estimate:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(req.approximateQuantity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Actual Verified Scale Weight:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Text(
                                '${actualWeight.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Note: The final payable amount is strictly computed from the actual scale weight.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
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
                  Navigator.pushReplacementNamed(context, '/amount-calculation', arguments: req.id);
                },
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Proceed to Amount Calculation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
