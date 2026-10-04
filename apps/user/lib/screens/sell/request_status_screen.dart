import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/material_item.dart';
import '../../models/sell_draft.dart';
import '../../models/sell_request.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/vendor_repository.dart';
import 'receive_upi_payment_screen.dart';

class RequestStatusScreen extends StatefulWidget {
  final String? requestId;
  final SellRequest? request;

  const RequestStatusScreen({super.key, this.requestId, this.request});

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  final SellRequestRepository _repository = SellRequestRepository();
  Timer? _pollTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChange);
    _refreshFromBackend();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshFromBackend(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _repository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  String? get _requestId =>
      widget.requestId ?? widget.request?.id ?? _repository.activeRequest?.id;

  SellRequest? get _req {
    final id = _requestId;
    if (id == null) return widget.request;
    return _repository.getRequestById(id) ?? widget.request;
  }

  Future<void> _refreshFromBackend({bool silent = false}) async {
    final id = _requestId;
    if (id == null) return;
    if (!silent && mounted) setState(() => _refreshing = true);
    await _repository.syncRequestFromBackend(id);
    if (!silent && mounted) setState(() => _refreshing = false);
  }

  String _statusBanner(SellRequest req) {
    switch (req.status) {
      case 'REQUEST_CREATED':
        return 'Request collector app ke Customer / Requests me bhej di gayi hai. Kabadiwala Accept ya Reject karega.';
      case 'KABADIWALA_ACCEPTED':
        return '${req.vendorName} ne Accept kar liya! Ab woh aapke address pe aayenge.';
      case 'PICKUP_SCHEDULED':
        return 'Pickup scheduled — kabadiwala ghar aa raha hai.';
      case 'SCRAP_COLLECTED':
        return 'Scrap collect ho gaya. Weight record ho raha hai.';
      case 'WEIGHT_RECORDED':
      case 'AMOUNT_CALCULATED':
        return 'Weight ke hisaab se amount ready. Continue to payment pe UPI scanner khulega — aapko paise milenge.';
      case 'PAYMENT_COMPLETED':
        return 'Payment receive ho gaya. Dhanyavaad!';
      case 'REJECTED':
        return '${req.vendorName} ne request Reject kar di. Dusra kabadiwala try karein.';
      default:
        return req.status.replaceAll('_', ' ');
    }
  }

  void _goPayment(SellRequest req) {
    final vendor = VendorRepository().getVendorById(req.vendorId) ??
        VendorRepository().connectedVendor;
    if (vendor == null) {
      Navigator.pushNamed(context, '/amount-calculation', arguments: req);
      return;
    }

    final weight = req.actualWeightKg ??
        double.tryParse(
          RegExp(r'(\d+(\.\d+)?)')
                  .firstMatch(req.approximateQuantity)
                  ?.group(1) ??
              '',
        ) ??
        15.0;

    final material = MaterialItem.defaultMaterials.firstWhere(
      (m) => m.category.toLowerCase() == req.materialCategory.toLowerCase(),
      orElse: () => MaterialItem.defaultMaterials.first,
    );

    final draft = SellDraft(
      vendor: vendor,
      lines: [SellLineItem(material: material, weightKg: weight)],
      mode: SellFulfillmentMode.pickup,
      pickupAddress: req.pickupLocation,
      preferredTime: req.preferredTime,
      note: req.note,
    );

    // Customer receives money — open UPI scanner, keep collector request linked.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveUpiPaymentScreen(
          draft: draft,
          existingRequestId: req.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _req;

    if (live == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Status')),
        body: const Center(child: Text('No request found')),
      );
    }

    final currentStep = live.currentStepIndex;
    final steps = SellRequest.workflowSteps;
    final waitingAccept = live.status == 'REQUEST_CREATED';
    final rejected = live.isRejected;
    final readyToPay = live.status == 'AMOUNT_CALCULATED' ||
        live.status == 'WEIGHT_RECORDED';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pickup request'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : () => _refreshFromBackend(),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshFromBackend(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: rejected
                    ? const Color(0xFFFFE4E6)
                    : waitingAccept
                        ? AppColors.accentSoft
                        : AppColors.primarySoft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        rejected
                            ? Icons.cancel_rounded
                            : waitingAccept
                                ? Icons.hourglass_top_rounded
                                : Icons.check_circle_rounded,
                        color: rejected
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusBanner(live),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (waitingAccept) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Collector app → Requests / Customer section me ye request dikhegi. Wahan Accept ya Reject karein — yahan auto update hoga.',
                            style: TextStyle(
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
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${live.materialCategory} · ${live.materialName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const Divider(height: 20),
                      _buildRow('Kabadiwala', live.vendorName),
                      _buildRow('Phone', live.vendorPhone),
                      _buildRow('Quantity Est.', live.approximateQuantity),
                      _buildRow('Preferred Time', live.preferredTime),
                      const SizedBox(height: 8),
                      const Text(
                        'Home address (pickup)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.home_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              live.pickupLocation,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (live.note != null && live.note!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildRow('Note', live.note!),
                      ],
                    ],
                  ),
                ),
              ),
              if (!rejected) ...[
                const SizedBox(height: 20),
                const Text(
                  'Pickup progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
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
                                        : (isCurrent
                                            ? AppColors.accent
                                            : AppColors.borderLight),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: isDone
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isCurrent
                                                  ? AppColors.primaryDark
                                                  : AppColors.textSecondary,
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
                                      fontWeight: isCurrent || isDone
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isCurrent || isDone
                                          ? AppColors.textMain
                                          : AppColors.textSecondary,
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
                                color: index < currentStep
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (readyToPay)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _goPayment(live),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Continue to payment'),
                  ),
                ),
              if (rejected) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/select-material'),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Choose another kabadiwala'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/home'),
                  child: const Text('Return to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
