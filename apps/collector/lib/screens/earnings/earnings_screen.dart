import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/transaction_card.dart';

class EarningsScreen extends StatefulWidget {
  final TransactionRepository? repository;

  const EarningsScreen({super.key, this.repository});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late final TransactionRepository _transactionRepository;
  final ConnectivityService _connectivityService = ConnectivityService.instance;

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  bool _isOffline = false;
  double _totalEarnings = 0.0;
  double _currentMonthEarnings = 0.0;
  double _pendingEarnings = 0.0;

  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _transactionRepository = widget.repository ?? TransactionRepository();
    _initConnectivityListener();
    _loadTransactions();
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        _loadTransactions();
      }
    });
  }

  Future<void> _loadTransactions({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final data = await _transactionRepository.fetchTransactions(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _transactions = data.transactions;
        _isOffline = data.isOffline;
        _totalEarnings = data.totalEarnings;
        _currentMonthEarnings = data.currentMonthEarnings;
        _pendingEarnings = data.pendingEarnings;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('earningsLedger')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: loc.translate('refreshLedger'),
            onPressed: () => _loadTransactions(forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Offline / Online Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _isOffline
                    ? AppColors.syncPending.withValues(alpha: 0.15)
                    : AppColors.syncSuccess.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(
                      _isOffline ? Icons.wifi_off_rounded : Icons.cloud_done_rounded,
                      size: 20,
                      color: _isOffline ? AppColors.syncPending : AppColors.syncSuccess,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isOffline
                            ? loc.translate('cachedOfflineLedger')
                            : loc.translate('liveLedger'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isOffline ? AppColors.syncPending : AppColors.syncSuccess,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Summary Card (Total & Month Earnings)
                    Card(
                      elevation: 4,
                      color: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Total Lifetime Earnings
                            Text(
                              loc.translate('totalEarnings'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Formatters.currency(_totalEarnings),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 28),

                            // Sub-row: Current Month & Pending Payouts
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Month Earnings
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.translate('currentMonthEarnings'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        Formatters.currency(_currentMonthEarnings),
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Pending Payouts
                                if (_pendingEarnings > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        loc.translate('pending'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        Formatters.currency(_pendingEarnings),
                                        style: const TextStyle(
                                          color: AppColors.syncPending,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.translate('allTransactions'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_transactions.length} ${loc.translate('recordedLots')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Transactions List / Empty State
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_transactions.isEmpty)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                size: 52,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                loc.translate('noTransactions'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return TransactionCard(transaction: tx);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
