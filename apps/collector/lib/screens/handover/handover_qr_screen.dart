import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/e_waste_lot.dart';
import '../../models/handover.dart';
import '../../models/recycler.dart';
import '../../repositories/handover_repository.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../earnings/earnings_screen.dart';
import '../recycler/recycler_handover_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _handoverRepo = widget.handoverRepository ?? HandoverRepository();
    _activeRecycler = widget.recycler ?? HandoverQrScreen.defaultRecycler;

    if (widget.initialHandover != null) {
      _handover = widget.initialHandover;
      _isLoading = false;
    } else {
      _initializeHandover();
    }
  }

  Future<void> _initializeHandover() async {
    setState(() => _isLoading = true);

    final lotId = widget.lot?.id ?? 'demo-lot-${DateTime.now().millisecondsSinceEpoch}';
    final material = widget.lot?.category ?? widget.lot?.categoryName ?? 'pcb';
    final weight = widget.lot?.weightKg ?? 5.0;
    final rate = _activeRecycler.indicativeRatePerKg > 0
        ? _activeRecycler.indicativeRatePerKg
        : 260.0;
    final agreedPrice = weight * rate;

    final handover = await _handoverRepo.createHandoverLocally(
      lotId: lotId,
      recyclerId: _activeRecycler.id,
      recyclerName: _activeRecycler.name,
      materialCategory: material,
      weightKg: weight,
      agreedPrice: agreedPrice,
    );

    if (mounted) {
      setState(() {
        _handover = handover;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    // Reuses the existing camera/scanner screen and route
    final result = await Navigator.pushNamed(context, '/camera');
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).translate('scanQr')}: ${_activeRecycler.name}',
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _simulateConfirmation() async {
    if (_handover == null || _isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      final updated = await _handoverRepo.confirmHandover(
        _handover!.id,
        finalAmount: _handover!.agreedPrice,
      );

      if (mounted) {
        setState(() {
          _handover = updated;
          _isConfirming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('handoverConfirmed'),
            ),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: AppLocalizations.of(context).translate('viewInLedger'),
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EarningsScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  void _navigateToPaymentForm() {
    final effectiveLot = widget.lot ??
        EWasteLot(
          id: _handover?.lotId ?? 'lot_demo_01',
          categoryId: _handover?.materialCategory ?? 'pcb',
          categoryName: _handover?.materialCategory.toUpperCase() ?? 'Motherboard / PCB',
          weightKg: _handover?.weightKg ?? 5.0,
          condition: 'good',
          estimatedMinPrice: (_handover?.agreedPrice ?? 1300) * 0.9,
          estimatedMaxPrice: (_handover?.agreedPrice ?? 1300) * 1.1,
          status: 'READY_FOR_HANDOVER',
          syncStatus: AppConstants.syncPending,
          createdAt: DateTime.now(),
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecyclerHandoverScreen(
          lot: effectiveLot,
          lotRepository: widget.lotRepository,
          transactionRepository: widget.transactionRepository,
        ),
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
        title: Text(loc.translate('handoverQr')),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: loc.translate('scanQr'),
            onPressed: _openScanner,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Status Header
                    _buildStatusHeader(loc),
                    const SizedBox(height: 16),

                    // 2. Prominent QR Code Card
                    _buildQrCard(loc),
                    const SizedBox(height: 16),

                    // 3. Prominent Scanner Card
                    _buildScannerCard(loc),
                    const SizedBox(height: 16),

                    // 4. Handover Details Card
                    _buildDetailsCard(loc),
                    const SizedBox(height: 20),

                    // 5. Actions / Simulation Button
                    if (isConfirmed)
                      _buildConfirmedAction(loc)
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

  Widget _buildQrCard(AppLocalizations loc) {
    final isConfirmed = _handover?.status == HandoverStatus.confirmed ||
        _handover?.status == AppConstants.handoverConfirmed;

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
            const SizedBox(height: 14),

            // QR Display
            if (_handover != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _handover!.qrPayload,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primaryDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Handover ID Preview
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
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy ID',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (_handover != null) {
                      Clipboard.setData(
                        ClipboardData(text: _handover!.id),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Handover ID copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCard(AppLocalizations loc) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: _openScanner,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryDark,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('scanQr'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.translate('scanQrPrompt') == 'scanQrPrompt'
                          ? 'Scan recycler code to verify authorization'
                          : loc.translate('scanQrPrompt'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
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

  Widget _buildConfirmedAction(AppLocalizations loc) {
    return SizedBox(
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingActions(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Demo Test Trigger
        _buildDemoTrigger(loc),
        const SizedBox(height: 14),

        // Optional step to open detailed weight & payment confirmation form
        OutlinedButton.icon(
          onPressed: _navigateToPaymentForm,
          icon: const Icon(Icons.edit_note_rounded, size: 22, color: AppColors.primaryDark),
          label: Text(
            loc.translate('handoverToRecycler'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoTrigger(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade200.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: Colors.amber.shade900),
              const SizedBox(width: 6),
              Text(
                'DEMO TEST TRIGGER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _simulateConfirmation,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text(
                loc.translate('confirmHandoverDemo'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
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
