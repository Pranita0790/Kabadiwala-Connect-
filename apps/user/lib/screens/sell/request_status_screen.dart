import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sell_request.dart';
import '../../repositories/sell_request_repository.dart';

class RequestStatusScreen extends StatefulWidget {
  final String? requestId;
  final SellRequest? request;

  const RequestStatusScreen({super.key, this.requestId, this.request});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  final SellRequestRepository _repository = SellRequestRepository();

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request ?? _repository.getRequestById(widget.requestId ?? '') ?? _repository.activeRequest;

    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Status')),
        body: const Center(child: Text('No request found')),
      );
    }

    final currentStep = req.currentStepIndex;
    final steps = SellRequest.workflowSteps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Timeline Status'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${req.materialCategory} • ${req.materialName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Step ${currentStep + 1} of 7',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildRow('Kabadiwala', req.vendorName),
                    _buildRow('Quantity Est.', req.approximateQuantity),
                    _buildRow('Preferred Time', req.preferredTime),
                    _buildRow('Location', req.pickupLocation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Pickup & Collection Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const SizedBox(height: 12),

            // Visual Progress Timeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: List.generate(steps.length, (index) {
                    final isDone = index < currentStep;
                    final isCurrent = index == currentStep;
                    final isLast = index == steps.length - 1;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? AppColors.primary
                                    : (isCurrent ? AppColors.accent : AppColors.borderLight),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent ? AppColors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isCurrent ? AppColors.primaryDark : AppColors.textSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                steps[index],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent || isDone ? AppColors.textMain : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isLast)
                          Container(
                            margin: const EdgeInsets.only(left: 15),
                            height: 24,
                            width: 2,
                            color: index < currentStep ? AppColors.primary : AppColors.border,
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Demo Simulation Control: Advance Step Button
            if (currentStep < steps.length - 1) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _repository.advanceRequestStatus(req.id);
                    final updated = _repository.getRequestById(req.id);
                    if (updated?.status == 'SCRAP_COLLECTED') {
                      Navigator.pushNamed(context, '/scrap-collection', arguments: req.id);
                    } else if (updated?.status == 'AMOUNT_CALCULATED') {
                      Navigator.pushNamed(context, '/amount-calculation', arguments: req.id);
                    } else if (updated?.status == 'PAYMENT_COMPLETED') {
                      Navigator.pushNamed(context, '/payment-result', arguments: req.id);
                    }
                  },
                  icon: const Icon(Icons.fast_forward),
                  label: Text('Simulate Next Workflow Step (${steps[currentStep + 1]})'),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Return to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
