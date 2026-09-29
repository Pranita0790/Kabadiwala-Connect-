import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/e_waste_lot.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../widgets/custom_button.dart';

class RecyclerHandoverScreen extends StatefulWidget {
  final EWasteLot lot;
  final TransactionRepository? transactionRepository;
  final LotRepository? lotRepository;

  const RecyclerHandoverScreen({
    super.key,
    required this.lot,
    this.transactionRepository,
    this.lotRepository,
  });

  @override
  State<RecyclerHandoverScreen> createState() => _RecyclerHandoverScreenState();
}

class _RecyclerHandoverScreenState extends State<RecyclerHandoverScreen> {
  late final TransactionRepository _transactionRepository;
  late final LotRepository _lotRepository;

  final List<String> _authorizedRecyclers = const [
    'EcoRecycle India (Nagpur Hub)',
    'GreenCircuits Formal Dismantlers',
    'Maharashtra E-Waste Recyclers',
  ];

  late String _selectedRecycler;
  late double _finalWeightKg;
  late double _agreedRatePerKg;
  String _paymentStatus = 'PAID';
  bool _isProcessing = false;
  bool _isCompleted = false;
  double _finalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _transactionRepository = widget.transactionRepository ?? TransactionRepository();
    _lotRepository = widget.lotRepository ?? LotRepository();

    _selectedRecycler = _authorizedRecyclers.first;
    _finalWeightKg = widget.lot.weightKg;

    // Calculate approximate rate per kg from estimated price
    final avgPrice = (widget.lot.estimatedMinPrice + widget.lot.estimatedMaxPrice) / 2;
    _agreedRatePerKg = widget.lot.weightKg > 0 ? (avgPrice / widget.lot.weightKg) : 250.0;
    _finalAmount = _finalWeightKg * _agreedRatePerKg;
  }

  void _recalculate() {
    setState(() {
      _finalAmount = _finalWeightKg * _agreedRatePerKg;
    });
  }

  Future<void> _handleConfirmHandover(AppLocalizations loc) async {
    setState(() => _isProcessing = true);

    // 1. Create Handover Transaction saved locally to SQLite
    await _transactionRepository.createHandoverTransaction(
      lotId: widget.lot.id,
      recyclerName: _selectedRecycler,
      categoryName: widget.lot.categoryName,
      weightKg: _finalWeightKg,
      quotedPrice: widget.lot.estimatedMinPrice,
      finalPrice: _finalAmount,
      paymentStatus: _paymentStatus,
    );

    // 2. Update Lot status in local database
    await _lotRepository.updateLotStatus(widget.lot.id, 'HANDED_OVER');

    setState(() {
      _isProcessing = false;
      _isCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_isCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('transactionStatus')),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.syncSuccess,
                size: 84,
              ),
              const SizedBox(height: 20),
              Text(
                loc.translate('handoverSuccess'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        loc.translate('finalAmount'),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.currency(_finalAmount),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.translate('paymentStatus')),
                          Text(
                            _paymentStatus == 'PAID' ? loc.translate('paid') : loc.translate('pending'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _paymentStatus == 'PAID' ? AppColors.syncSuccess : AppColors.syncPending,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: loc.translate('viewInLedger'),
                icon: Icons.account_balance_wallet,
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  Navigator.pushNamed(context, '/earnings');
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: loc.translate('home'),
                icon: Icons.home,
                isSecondary: true,
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('handoverToRecycler')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lot.categoryName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loc.translate('weight')}: ${Formatters.weight(widget.lot.weightKg)} • ${widget.lot.condition.toUpperCase()}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 1. Select Recycler
            Text(
              loc.translate('selectRecycler'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedRecycler,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _authorizedRecyclers.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(fontSize: 15)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRecycler = val);
                }
              },
            ),
            const SizedBox(height: 20),

            // 2. Confirmed Final Weight
            Text(
              loc.translate('enterWeight'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.weight(_finalWeightKg),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 32),
                          onPressed: () {
                            setState(() {
                              _finalWeightKg = (_finalWeightKg - 0.5).clamp(0.5, 1000.0);
                              _recalculate();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 32, color: AppColors.primary),
                          onPressed: () {
                            setState(() {
                              _finalWeightKg += 0.5;
                              _recalculate();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Payment Status Selector
            Text(
              loc.translate('paymentStatus'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Container(
                      alignment: Alignment.center,
                      height: 40,
                      child: Text(
                        loc.translate('paid'),
                        style: TextStyle(
                          color: _paymentStatus == 'PAID' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selected: _paymentStatus == 'PAID',
                    selectedColor: AppColors.syncSuccess,
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) setState(() => _paymentStatus = 'PAID');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Container(
                      alignment: Alignment.center,
                      height: 40,
                      child: Text(
                        loc.translate('pending'),
                        style: TextStyle(
                          color: _paymentStatus == 'PENDING' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selected: _paymentStatus == 'PENDING',
                    selectedColor: AppColors.syncPending,
                    backgroundColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) setState(() => _paymentStatus = 'PENDING');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total Agreed Payout Card
            Card(
              color: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('finalAmount'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.currency(_finalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Confirm Handover Button
            CustomButton(
              label: loc.translate('confirmHandover'),
              icon: Icons.check_circle_outline,
              isLoading: _isProcessing,
              onPressed: () => _handleConfirmHandover(loc),
            ),
          ],
        ),
      ),
    );
  }
}
