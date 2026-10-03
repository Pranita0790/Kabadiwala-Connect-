import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sell_request.dart';
import '../../repositories/sell_request_repository.dart';

class PickupDetailsScreen extends StatelessWidget {
  final String? requestId;
  final SellRequest? request;

  const PickupDetailsScreen({super.key, this.requestId, this.request});

  @override
  Widget build(BuildContext context) {
    final repo = SellRequestRepository();
    final req = request ?? repo.getRequestById(requestId ?? '') ?? repo.activeRequest;

    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pickup Details')),
        body: const Center(child: Text('Pickup request not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doorstep Pickup Details'),
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
                      'Pickup Request Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Divider(height: 24),
                    _buildRow('Material', '${req.materialCategory} • ${req.materialName}'),
                    _buildRow('Approx. Quantity', req.approximateQuantity),
                    _buildRow('Assigned Kabadiwala', req.vendorName),
                    _buildRow('Vendor Contact', req.vendorPhone),
                    _buildRow('Preferred Time Slot', req.preferredTime),
                    _buildRow('Pickup Location', req.pickupLocation),
                    if (req.note != null && req.note!.isNotEmpty) _buildRow('Customer Note', req.note!),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Request Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            req.status.replaceAll('_', ' '),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 12),
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
                  Navigator.pushNamed(context, '/request-status', arguments: req.id);
                },
                icon: const Icon(Icons.timeline),
                label: const Text('View Live Progress Timeline'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
