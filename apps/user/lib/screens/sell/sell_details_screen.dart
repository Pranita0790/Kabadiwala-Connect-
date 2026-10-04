import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sell_draft.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/vendor_repository.dart';
import 'receive_upi_payment_screen.dart';
import 'request_status_screen.dart';

/// Pickup: send request to kabadiwala first.
/// Shop visit: Continue to payment → UPI receive scanner (customer gets paid).
class SellDetailsScreen extends StatefulWidget {
  final SellDraft draft;

  const SellDetailsScreen({super.key, required this.draft});

  @override
  State<SellDetailsScreen> createState() => _SellDetailsScreenState();
}

class _SellDetailsScreenState extends State<SellDetailsScreen> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  String _timeSlot = 'Today, 4:00 PM - 6:00 PM';
  bool _busy = false;

  final _timeSlots = const [
    'Today, 4:00 PM - 6:00 PM',
    'Tomorrow, 10:00 AM - 12:00 PM',
    'Tomorrow, 2:00 PM - 4:00 PM',
    'Weekend, Morning Slot',
  ];

  bool get _isPickup => widget.draft.mode == SellFulfillmentMode.pickup;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(
      text: widget.draft.pickupAddress ?? 'B-402, Green Acres, Andheri East',
    );
    _noteCtrl = TextEditingController(text: widget.draft.note ?? '');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  SellDraft _buildDraft() {
    return widget.draft.copyWith(
      pickupAddress: _isPickup
          ? _addressCtrl.text.trim()
          : widget.draft.vendor.address,
      preferredTime: _isPickup ? _timeSlot : 'Shop visit · anytime during hours',
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
  }

  Future<void> _submitPickupRequest() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter pickup address')),
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);

    final draft = _buildDraft();
    final vendor = draft.vendor;
    VendorRepository().connectVendor(vendor.id);

    final request = await SellRequestRepository().createRequest(
      materialName: draft.primaryMaterialName,
      materialCategory: draft.primaryCategory,
      approximateQuantity: '${draft.totalWeightKg.toStringAsFixed(1)} kg',
      pickupLocation: draft.pickupAddress!,
      preferredTime: draft.preferredTime!,
      note: [
        'MODE:PICKUP',
        'Est. ₹${draft.estimatedAmount.toStringAsFixed(0)}',
        'Items: ${draft.materialsSummary}',
        if (draft.note != null) draft.note!,
      ].join(' | '),
      vendor: vendor,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request sent to ${vendor.name}. Accept hone ke baad woh is address pe aayenge.',
        ),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RequestStatusScreen(request: request),
      ),
    );
  }

  Future<void> _goShopPayment() async {
    if (_busy) return;
    final draft = _buildDraft();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveUpiPaymentScreen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = widget.draft.vendor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isPickup ? 'Pickup details' : 'Shop visit details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPickup
                          ? 'Kabadiwala ghar aayega'
                          : 'Aap dukan pe jayenge (Direct Cash)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vendor.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            vendor.address,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Est. payout ₹${widget.draft.estimatedAmount.toStringAsFixed(0)} · ${widget.draft.totalWeightKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isPickup) ...[
              const SizedBox(height: 12),
              Card(
                color: AppColors.primarySoft,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Iske baad request kabadiwala ko jayegi. Jab woh accept karega, tab woh aapke diye hue address pe ghar aayega.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_isPickup) ...[
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Your pickup address',
                  prefixIcon: Icon(Icons.home_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _timeSlot,
                decoration: const InputDecoration(
                  labelText: 'Preferred time',
                  prefixIcon: Icon(Icons.access_time, color: AppColors.primary),
                ),
                items: _timeSlots
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _timeSlot = v);
                },
              ),
              const SizedBox(height: 14),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shop hours: ${vendor.operatingHours}. '
                          'Continue to payment pe UPI scanner/app khulega — '
                          'aap payment nahi karte, aapko paise milte hain. '
                          'Request collector app se linked rehti hai.',
                          style: const TextStyle(
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
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Gate code / call before arrival',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : (_isPickup ? _submitPickupRequest : _goShopPayment),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_isPickup ? Icons.send_rounded : Icons.payments_outlined),
              label: Text(
                _busy
                    ? 'Sending request…'
                    : (_isPickup
                        ? 'Send pickup request'
                        : 'Continue to payment'),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
