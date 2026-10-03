import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pickup_request.dart';
import '../../repositories/pickup_request_repository.dart';
import 'payment_screen.dart';

class CollectionScreen extends StatefulWidget {
  final String requestId;

  const CollectionScreen({super.key, required this.requestId});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final PickupRequestRepository _repository = PickupRequestRepository();
  final TextEditingController _weightController = TextEditingController();
  bool _isLoading = true;
  PickupRequest? _request;
  double _actualWeight = 0.0;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    setState(() => _isLoading = true);
    final req = await _repository.getRequestById(widget.requestId);
    setState(() {
      _request = req;
      if (req != null) {
        _weightController.text = req.estimatedWeightKg > 0 ? req.estimatedWeightKg.toString() : '';
        _actualWeight = req.estimatedWeightKg;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Collection')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Collection')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final req = _request!;
    final double calculatedFinalAmount = _actualWeight * req.ratePerKg;

    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: const Text('Record Collection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.userName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            '${req.materialCategory} • ${req.materialName}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weight Input Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Actual Measured Weight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Actual Weight (kg)',
                        suffixText: 'kg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.scale, color: AppColors.primary),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _actualWeight = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Estimated by customer: ${req.estimatedWeightKg} kg',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calculation Breakdown Card
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rate & Amount Calculation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Divider(height: 24),
                    _buildRow('Buying Rate (Snapshot)', '₹${req.ratePerKg.toStringAsFixed(0)} / kg'),
                    const SizedBox(height: 8),
                    _buildRow('Measured Weight', '${_actualWeight.toStringAsFixed(2)} kg'),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable Amount',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        Text(
                          '₹${calculatedFinalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.clayOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actualWeight > 0
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentScreen(
                              requestId: req.id,
                              actualWeightKg: _actualWeight,
                              finalAmount: calculatedFinalAmount,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.payment),
                label: const Text('Proceed to Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
      ],
    );
  }
}
