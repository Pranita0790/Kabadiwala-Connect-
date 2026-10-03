import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/e_waste_lot.dart';
import '../../models/handover.dart';
import '../../models/recycler.dart';
import '../../repositories/handover_repository.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../earnings/earnings_screen.dart';

class HandoverQrScreen extends StatefulWidget {
  final Recycler? recycler;
  final EWasteLot? lot;
  final Handover? initialHandover;
  final HandoverRepository? handoverRepository;
  final LotRepository? lotRepository;
  final TransactionRepository? transactionRepository;

  static const Recycler defaultRecycler = Recycler(
    id: 'rec_01',
    name: 'EcoRecycle Maharashtra',
    address: 'Plot 42, MIDC Hingna Industrial Area, Nagpur',
    acceptedCategories: ['pcb', 'copper_wire', 'battery', 'display', 'appliances', 'mixed'],
    distanceKm: 2.4,
    isAuthorized: true,
    rating: 4.8,
    contactPhone: '+91 98230 11223',
    latitude: 21.1458,
    longitude: 79.0882,
    indicativePrice: 320.0,
    unit: 'kg',
    isDemo: true,
  );

  const HandoverQrScreen({
    super.key,
    this.recycler,
    this.lot,
    this.initialHandover,
    this.handoverRepository,
    this.lotRepository,
    this.transactionRepository,
  });

  @override
  State<HandoverQrScreen> createState() => _HandoverQrScreenState();
}

class _HandoverQrScreenState extends State<HandoverQrScreen> {
  late final HandoverRepository _handoverRepo;
  late Recycler _activeRecycler;

  Handover? _handover;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _missingLot = false;
  bool _paymentReceived = false;
  double _receiptAmount = 0;

  /// Cash | UPI — preferred method for the recycler website to honour.
  String _paymentMethod = 'CASH';
  String _paymentStatus = 'PAID';
  final TextEditingController _upiRefController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _handoverRepo = widget.handoverRepository ?? HandoverRepository();
    _activeRecycler = widget.recycler ?? HandoverQrScreen.defaultRecycler;

    if (widget.initialHandover != null) {
      _handover = widget.initialHandover;
      _isLoading = false;
      _startPaymentPoll();
    } else {
      _initializeHandover();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _upiRefController.dispose();
    super.dispose();
  }

  void _startPaymentPoll() {
    _pollTimer?.cancel();
    unawaited(_checkRemotePayment());
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_checkRemotePayment());
    });
  }

  Future<void> _checkRemotePayment() async {
    final lotId = widget.lot?.id ?? _handover?.lotId;
    final handover = _handover;
    if (lotId == null ||
        handover == null ||
        _paymentReceived ||
        !mounted ||
        handover.status == AppConstants.handoverConfirmed) {
      return;
    }
    try {
      await NotificationService.instance.pullFromBackend();

      // Only treat PAID rows created AFTER this handover as website confirmation.
      final repo = widget.transactionRepository ?? TransactionRepository();
      final ledger = await repo.fetchTransactions(forceRefresh: true);
      final handoverStarted = handover.createdAt.subtract(const Duration(seconds: 5));
      final paid = ledger.transactions.where((tx) {
        final sameLot = tx.lotId == lotId ||
            tx.lotId == handover.lotId ||
            tx.lotId == handover.id;
        final status = tx.paymentStatus.toUpperCase();
        final isPaid = status == 'PAID' || status == 'RECEIVED';
        final afterHandover = !tx.createdAt.isBefore(handoverStarted);
        return sameLot && isPaid && afterHandover;
      }).toList();

      // Backend payment inbox (HANDOVER_CONFIRMED / Payment received).
      final notes = await NotificationService.instance.getNotifications();
      final paidNote = notes.where((n) {
        if (n.isDemo) return false;
        final type = n.type.toUpperCase();
        final body = '${n.titleEn} ${n.bodyEn}'.toLowerCase();
        final isPayNote = type == AppConstants.notificationHandover ||
            type.contains('HANDOVER') ||
            body.contains('payment received') ||
            body.contains('paid');
        if (!isPayNote) return false;
        final related = n.relatedId ?? '';
        final matchesLot = related.isEmpty ||
            related == lotId ||
            related == handover.id ||
            related == handover.lotId ||
            body.contains(lotId.toLowerCase());
        final afterHandover = !n.timestamp.isBefore(handoverStarted);
        return matchesLot && afterHandover;
      }).toList();

      if ((paid.isEmpty && paidNote.isEmpty) || !mounted) return;
      final amount = paid.isNotEmpty
          ? paid.first.finalPrice
          : handover.agreedPrice;

      // Ledger rows come from GET /transactions/my (already saved above).
      // Mark local handover confirmed so this screen stops waiting.
      try {
        await DatabaseService.instance.updateHandoverStatus(
          handover.id,
          AppConstants.handoverConfirmed,
          confirmedAt: DateTime.now(),
        );
      } catch (_) {}

      await NotificationService.instance.notifyRecyclerPayment(
        recyclerName: _activeRecycler.name,
        amount: amount,
        lotId: lotId,
      );
      if (!mounted) return;
      setState(() {
        _paymentReceived = true;
        _receiptAmount = amount;
        _handover = _handover?.copyWith(status: AppConstants.handoverConfirmed);
      });
    } catch (_) {}
  }

  Future<void> _initializeHandover() async {
    if (widget.lot == null) {
      setState(() {
        _missingLot = true;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final lot = widget.lot!;
    final rate = _activeRecycler.indicativeRatePerKg > 0
        ? _activeRecycler.indicativeRatePerKg
        : ((lot.estimatedMinPrice + lot.estimatedMaxPrice) / 2) /
            (lot.weightKg <= 0 ? 1 : lot.weightKg);
    final agreedPrice = lot.weightKg * rate;

    final handover = await _handoverRepo.createHandoverLocally(
      lot: lot,
      recycler: _activeRecycler,
      agreedPrice: agreedPrice,
    );

    if (mounted) {
      setState(() {
        _handover = handover;
        _isLoading = false;
      });
      _startPaymentPoll();
    }
  }

  Future<void> _retrySendToWebsite() async {
    if (_handover == null || _isConfirming) return;
    setState(() => _isConfirming = true);
    final updated = await _handoverRepo.pushToWebsite(
      _handover!,
      lot: widget.lot,
    );
    if (!mounted) return;
    setState(() {
      _handover = updated;
      _isConfirming = false;
    });
    final loc = AppLocalizations.of(context);
    final ok = updated.syncStatus == AppConstants.syncSynced;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? loc.translate('lotOnWebsite') : loc.translate('handoverRemoteFailed'),
        ),
        backgroundColor: ok ? AppColors.syncSuccess : Colors.orange.shade800,
      ),
    );
  }

  void _copyPin(String pin, AppLocalizations loc) {
    Clipboard.setData(ClipboardData(text: pin));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.translate('pinCopied')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final isConfirmed = _handover?.status == HandoverStatus.confirmed ||
        _handover?.status == AppConstants.handoverConfirmed;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('handoverPin')),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _missingLot
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.translate('handoverNeedsLot'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(loc.translate('saveLot')),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusHeader(loc),
                        const SizedBox(height: 16),
                        _buildPinCard(loc),
                        const SizedBox(height: 16),
                        if (!isConfirmed) ...[
                          _buildPaymentCard(loc),
                          const SizedBox(height: 16),
                        ],
                        _buildDetailsCard(loc),
                        const SizedBox(height: 20),
                        if (isConfirmed || _paymentReceived)
                          _buildReceiptCard(loc)
                        else
                          _buildPendingActions(loc),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusHeader(AppLocalizations loc) {
    final isConfirmed = _handover?.status == HandoverStatus.confirmed ||
        _handover?.status == AppConstants.handoverConfirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isConfirmed
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConfirmed ? AppColors.primary : Colors.amber.shade600,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.hourglass_top_rounded,
            color: isConfirmed ? AppColors.primary : Colors.amber.shade900,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConfirmed
                  ? loc.translate('handoverConfirmed')
                  : loc.translate('waitingForConfirmation'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isConfirmed ? AppColors.primaryDark : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard(AppLocalizations loc) {
    final isConfirmed = _handover?.status == HandoverStatus.confirmed ||
        _handover?.status == AppConstants.handoverConfirmed;
    final pinSeed = widget.lot?.id ?? _handover?.lotId ?? '';
    final pin = pinSeed.isEmpty
        ? '------'
        : Handover.deriveHandoverPin(pinSeed);

    return Card(
      elevation: isConfirmed ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isConfirmed ? AppColors.primary : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            Text(
              loc.translate('readyForHandover'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate('handoverPinHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Text(
                    loc.translate('handoverPin'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pin,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: pinSeed.isEmpty
                        ? null
                        : () => _copyPin(pin, loc),
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: loc.translate('pinCopied'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  '${loc.translate('handoverId')}: ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _handover != null && _handover!.id.isNotEmpty
                      ? (_handover!.id.length >= 8
                          ? _handover!.id.substring(0, 8).toUpperCase()
                          : _handover!.id.toUpperCase())
                      : '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(AppLocalizations loc) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.translate('paymentMethod'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          loc.translate('payCash'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _paymentMethod == 'CASH' ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    selected: _paymentMethod == 'CASH',
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _paymentMethod = 'CASH';
                          _paymentStatus = 'PAID';
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          loc.translate('payUpi'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _paymentMethod == 'UPI' ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    selected: _paymentMethod == 'UPI',
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _paymentMethod = 'UPI');
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_paymentMethod == 'UPI') ...[
              const SizedBox(height: 14),
              Text(
                loc.translate('paymentStatus'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(loc.translate('paid')),
                      selected: _paymentStatus == 'PAID',
                      selectedColor: AppColors.syncSuccess,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _paymentStatus == 'PAID' ? Colors.white : Colors.black87,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _paymentStatus = 'PAID');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(loc.translate('pending')),
                      selected: _paymentStatus == 'PENDING',
                      selectedColor: AppColors.syncPending,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _paymentStatus == 'PENDING' ? Colors.white : Colors.black87,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _paymentStatus = 'PENDING');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiRefController,
                decoration: InputDecoration(
                  labelText: loc.translate('upiRefHint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(AppLocalizations loc) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            _DetailRow(
              label: loc.translate('material'),
              value: loc.translate('category${_capitalize(_handover?.materialCategory ?? '')}') ==
                      'category${_capitalize(_handover?.materialCategory ?? '')}'
                  ? (_handover?.materialCategory.toUpperCase() ?? '')
                  : loc.translate('category${_capitalize(_handover?.materialCategory ?? '')}'),
              icon: Icons.category_rounded,
            ),
            const Divider(height: 18),
            _DetailRow(
              label: loc.translate('weight'),
              value: '${_handover?.weightKg.toStringAsFixed(1)} kg',
              icon: Icons.scale_rounded,
            ),
            const Divider(height: 18),
            _DetailRow(
              label: loc.translate('recycler'),
              value: _activeRecycler.name,
              icon: Icons.business_rounded,
            ),
            const Divider(height: 18),
            _DetailRow(
              label: loc.translate('lotRefLabel'),
              value: widget.lot?.id ?? _handover?.lotId ?? '—',
              icon: Icons.tag_rounded,
            ),
            const Divider(height: 18),
            _DetailRow(
              label: loc.translate('finalAmount'),
              value: '₹${_handover?.agreedPrice.toStringAsFixed(0)}',
              icon: Icons.currency_rupee_rounded,
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(AppLocalizations loc) {
    final amount = _receiptAmount > 0
        ? _receiptAmount
        : (_handover?.agreedPrice ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.syncSuccess, size: 56),
                const SizedBox(height: 12),
                Text(
                  loc.translate('paymentReceiptTitle'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.translate('paymentFromRecycler'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  _activeRecycler.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  Formatters.currency(amount),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const EarningsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 22),
            label: Text(
              loc.translate('viewInLedger'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingActions(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            loc.translate('waitingForRecyclerPay'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        if (_handover?.syncStatus == AppConstants.syncSynced)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              loc.translate('lotOnWebsite'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _retrySendToWebsite,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                loc.translate('sendLotToWebsite'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isHighlighted ? AppColors.primary : AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
