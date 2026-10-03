class PaymentRecord {
  final String id;
  final double amount;
  final DateTime date;
  final String materialName;
  final double weightKg;
  final String status; // 'PAID', 'PENDING', 'PROCESSING'
  final String referenceNo;
  final String vendorName;

  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.date,
    required this.materialName,
    required this.weightKg,
    this.status = 'PAID',
    required this.referenceNo,
    required this.vendorName,
  });

  String get paymentMethod => 'UPI';
  String get itemsSummary => materialName;
  String get formattedDate => '${date.day}/${date.month}/${date.year}';
  String get transactionId => referenceNo;

  static List<PaymentRecord> get sampleHistory => [
        PaymentRecord(
          id: 'pay_772',
          amount: 772.80,
          date: DateTime(2026, 10, 2),
          materialName: 'Metal (Iron & Copper)',
          weightKg: 18.4,
          status: 'PAID',
          referenceNo: 'KC-PAY-20261002-88',
          vendorName: 'Ramesh Kumar',
        ),
        PaymentRecord(
          id: 'pay_340',
          amount: 340.00,
          date: DateTime(2026, 9, 24),
          materialName: 'Paper & Cardboard',
          weightKg: 20.0,
          status: 'PAID',
          referenceNo: 'KC-PAY-20260924-12',
          vendorName: 'Ramesh Kumar',
        ),
        PaymentRecord(
          id: 'pay_560',
          amount: 560.00,
          date: DateTime(2026, 9, 10),
          materialName: 'PET Bottles & Plastic',
          weightKg: 20.0,
          status: 'PAID',
          referenceNo: 'KC-PAY-20260910-04',
          vendorName: 'Vijay Scrap Traders',
        ),
      ];
}
