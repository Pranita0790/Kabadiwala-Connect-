import 'package:flutter/foundation.dart';
import '../models/payment_record.dart';

class PaymentRepository extends ChangeNotifier {
  static final PaymentRepository _instance = PaymentRepository._internal();
  factory PaymentRepository() => _instance;
  PaymentRepository._internal();

  final List<PaymentRecord> _payments = List.from(PaymentRecord.sampleHistory);

  List<PaymentRecord> get payments => List.unmodifiable(_payments);

  double get totalEarned => _payments.fold(0.0, (sum, p) => sum + p.amount);
  double get totalWeightRecycled => _payments.fold(0.0, (sum, p) => sum + p.weightKg);

  static List<PaymentRecord> getSamplePayments() {
    return _instance.payments;
  }

  void addPayment(PaymentRecord record) {
    _payments.insert(0, record);
    notifyListeners();
  }
}
