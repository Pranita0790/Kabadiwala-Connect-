import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class TransactionLedgerData {
  final List<Transaction> transactions;
  final bool isOffline;
  final DateTime? lastUpdated;

  TransactionLedgerData({
    required this.transactions,
    required this.isOffline,
    this.lastUpdated,
  });

  /// Total lifetime money earned from paid transactions
  double get totalEarnings {
    return transactions
        .where((tx) =>
            tx.paymentStatus.toUpperCase() == 'PAID' ||
            tx.paymentStatus.toUpperCase() == 'RECEIVED')
        .fold(0.0, (sum, tx) => sum + tx.finalPrice);
  }

  /// Earnings accrued in the current calendar month
  double get currentMonthEarnings {
    final now = DateTime.now();
    return transactions
        .where((tx) {
          final isPaid = tx.paymentStatus.toUpperCase() == 'PAID' ||
              tx.paymentStatus.toUpperCase() == 'RECEIVED';
          final isThisMonth = tx.createdAt.year == now.year &&
              tx.createdAt.month == now.month;
          return isPaid && isThisMonth;
        })
        .fold(0.0, (sum, tx) => sum + tx.finalPrice);
  }

  /// Pending payout amount
  double get pendingEarnings {
    return transactions
        .where((tx) => tx.paymentStatus.toUpperCase() == 'PENDING')
        .fold(0.0, (sum, tx) => sum + tx.finalPrice);
  }
}

class TransactionRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;

  TransactionRepository({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
  })  : _dbService = dbService ?? DatabaseService(),
        _apiService = apiService ?? RemoteApiService(),
        _connectivityService = connectivityService ?? ConnectivityService();

  /// Fetches collector earnings and transaction history:
  ///
  /// - Online: Fetches latest completed transactions from API and caches locally in SQLite.
  /// - Offline: Reads cached transactions from SQLite without failing or depending on network.
  Future<TransactionLedgerData> fetchTransactions({bool forceRefresh = false}) async {
    final isConnected = await _connectivityService.isConnected();

    if (isConnected) {
      try {
        final response = await _apiService.fetchMyTransactions();
        if (response.success && response.data != null) {
          // Cache each transaction in local SQLite
          for (final tx in response.data!) {
            await _dbService.insertTransaction(tx);
          }
          return TransactionLedgerData(
            transactions: response.data!,
            isOffline: false,
            lastUpdated: DateTime.now(),
          );
        }
      } catch (_) {
        // Fallback to SQLite cache on API error
      }
    }

    // Offline / Fallback Flow: Read from local SQLite
    final localTransactions = await _dbService.getTransactions();
    return TransactionLedgerData(
      transactions: localTransactions,
      isOffline: true,
      lastUpdated: localTransactions.isNotEmpty ? localTransactions.first.createdAt : null,
    );
  }

  // Alias for backward compatibility
  Future<List<Transaction>> getTransactions() async {
    final data = await fetchTransactions();
    return data.transactions;
  }

  /// Creates a local handover transaction and persists it to SQLite
  Future<Transaction> createHandoverTransaction({
    required String lotId,
    required String recyclerName,
    required String categoryName,
    required double weightKg,
    required double quotedPrice,
    required double finalPrice,
    required String paymentStatus,
  }) async {
    final now = DateTime.now();
    final tx = Transaction(
      id: 'tx_local_${now.millisecondsSinceEpoch}',
      lotId: lotId,
      recyclerId: recyclerName,
      categoryName: categoryName,
      weightKg: weightKg,
      quotedPrice: quotedPrice,
      finalPrice: finalPrice,
      paymentStatus: paymentStatus,
      handoverStatus: 'COMPLETED',
      createdAt: now,
    );

    // Persist locally to SQLite
    await _dbService.insertTransaction(tx);
    return tx;
  }
}
