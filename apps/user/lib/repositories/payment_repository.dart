import 'package:flutter/foundation.dart';
import '../models/collection_record.dart';
import '../models/payment_record.dart';
import 'collection_repository.dart';

class PaymentRepository extends ChangeNotifier {
  static final PaymentRepository _instance = PaymentRepository._internal();
  factory PaymentRepository() => _instance;
  PaymentRepository._internal();

  final List<PaymentRecord> _payments = List.from(PaymentRecord.sampleHistory);

  List<PaymentRecord> get payments => List.unmodifiable(_payments);

  double get totalEarned => _payments.fold(0.0, (sum, p) => sum + p.amount);
  double get totalWeightRecycled =>
      _payments.fold(0.0, (sum, p) => sum + p.weightKg);
  int get transactionCount => _payments.length;

  static List<PaymentRecord> getSamplePayments() {
    return _instance.payments;
  }

  void addPayment(PaymentRecord record) {
    final exists = _payments.any((p) => p.id == record.id || p.referenceNo == record.referenceNo);
    if (exists) return;
    _payments.insert(0, record);
    // Keep collection history in sync for previous-flow screens.
    CollectionRepository().addCollection(
      CollectionRecord(
        id: 'col_${record.id}',
        date: record.date,
        materialName: record.materialName,
        approximateQuantity: '${record.weightKg.toStringAsFixed(1)} kg',
        actualWeightKg: record.weightKg,
        ratePerKg: record.weightKg > 0 ? record.amount / record.weightKg : 0,
        totalAmount: record.amount,
        vendorName: record.vendorName,
        paymentStatus: record.status,
      ),
    );
    notifyListeners();
  }
}
