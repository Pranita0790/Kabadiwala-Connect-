import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pickup_request.dart';
import '../../repositories/pickup_request_repository.dart';
import '../collection/collection_screen.dart';

class RequestDetailsScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailsScreen({super.key, required this.requestId});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final PickupRequestRepository _repository = PickupRequestRepository();
  bool _isLoading = true;
  PickupRequest? _request;

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    setState(() => _isLoading = true);
    final req = await _repository.getRequestById(widget.requestId);
    setState(() {
      _request = req;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_request == null) return;
    try {
      final updated = await _repository.updateRequestStatus(_request!.id, newStatus);
      setState(() => _request = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _makePhoneCall(String phoneNumber) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Call Customer'),
          ],
        ),
        content: Text('Contact customer at: $phoneNumber'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: Text('Pickup request not found')),
      );
    }

    final req = _request!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, req.status);
      },
      child: Scaffold(
        backgroundColor: AppColors.limeBackground,
        appBar: AppBar(
          title: const Text('Pickup Request'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, req.status),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header Banner
              _buildStatusHeader(req),
              const SizedBox(height: 16),

              // Customer Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(25),
                            child: const Icon(Icons.person, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.userName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  req.userPhone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => _makePhoneCall(req.userPhone),
                            icon: const Icon(Icons.phone, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 20, color: AppColors.clayOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              req.pickupAddress,
                              style: const TextStyle(fontSize: 14, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 20, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Slot: ${req.preferredTimeSlot}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scrap Material Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scrap Material Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Divider(height: 20),
                      _buildDetailRow('Category', req.materialCategory),
                      _buildDetailRow('Material Name', req.materialName),
                      _buildDetailRow('Estimated Weight', '${req.estimatedWeightKg} kg'),
                      _buildDetailRow('Applicable Rate', '₹${req.ratePerKg.toStringAsFixed(0)} / kg'),
                      _buildDetailRow('Estimated Total', '₹${(req.estimatedWeightKg * req.ratePerKg).toStringAsFixed(0)}'),

                      if (req.description != null && req.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Customer Notes:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            req.description!,
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ),
                      ],

                      if (req.status == 'COMPLETED') ...[
                        const Divider(height: 24),
                        const Text(
                          'Collection Completion Summary',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Actual Weight', '${req.actualWeightKg ?? 0.0} kg'),
                        _buildDetailRow('Final Amount Paid', '₹${req.finalAmount?.toStringAsFixed(0) ?? "0"}'),
                        _buildDetailRow('Payment Method', req.paymentMethod ?? 'CASH'),
                        _buildDetailRow('Payment Status', req.paymentStatus),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Actions
              _buildActionButtons(req),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(PickupRequest req) {
    Color bg;
    String label;
    IconData icon;

    switch (req.status) {
      case 'PENDING':
        bg = AppColors.clayOrange;
        label = 'New Pickup Request Pending';
        icon = Icons.pending_actions;
        break;
      case 'ACCEPTED':
        bg = Colors.blue;
        label = 'Pickup Request Accepted';
        icon = Icons.check_circle_outline;
        break;
      case 'ON_MY_WAY':
        bg = Colors.indigo;
        label = 'Collector is On The Way';
        icon = Icons.directions_bike;
        break;
      case 'COLLECTING':
        bg = Colors.purple;
        label = 'Collection in Progress';
        icon = Icons.scale;
        break;
      case 'COMPLETED':
        bg = AppColors.secondary;
        label = 'Pickup Completed & Paid';
        icon = Icons.verified;
        break;
      default:
        bg = AppColors.textMuted;
        label = req.status;
        icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PickupRequest req) {
    if (req.status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateStatus('REJECTED'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.clayPink,
                side: const BorderSide(color: AppColors.clayPink, width: 1.5),
              ),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateStatus('ACCEPTED'),
              child: const Text('Accept Request'),
            ),
          ),
        ],
      );
    } else if (req.status == 'ACCEPTED') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus('ON_MY_WAY'),
          icon: const Icon(Icons.directions_bike),
          label: const Text('On My Way'),
        ),
      );
    } else if (req.status == 'ON_MY_WAY' || req.status == 'COLLECTING') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CollectionScreen(requestId: req.id),
              ),
            );
            _loadRequestDetails();
          },
          icon: const Icon(Icons.scale),
          label: const Text('Start Collection'),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, req.status),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Requests'),
        ),
      );
    }
  }
}
