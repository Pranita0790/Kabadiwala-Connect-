class CollectionItem {
  final String materialName;
  final double weightKg;
  final double ratePerKg;
  final double subtotal;

  CollectionItem({
    required this.materialName,
    required this.weightKg,
    required this.ratePerKg,
    required this.subtotal,
  });
}

class CollectionRecord {
  final String id;
  final DateTime date;
  final String materialName;
  final String approximateQuantity;
  final double actualWeightKg;
  final double ratePerKg;
  final double totalAmount;
  final String vendorName;
  final String paymentStatus;

  const CollectionRecord({
    required this.id,
    required this.date,
    required this.materialName,
    required this.approximateQuantity,
    required this.actualWeightKg,
    required this.ratePerKg,
    required this.totalAmount,
    required this.vendorName,
    this.paymentStatus = 'PAID',
  });

  double get totalWeightKg => actualWeightKg;
  String get formattedDate => '${date.day}/${date.month}/${date.year}';
  String get paymentMethod => 'UPI';

  List<CollectionItem> get items => [
        CollectionItem(
          materialName: materialName,
          weightKg: actualWeightKg,
          ratePerKg: ratePerKg,
          subtotal: totalAmount,
        )
      ];

  static List<CollectionRecord> get sampleCollections => [
        CollectionRecord(
          id: 'col_101',
          date: DateTime(2026, 10, 2),
          materialName: 'Metals & Heavy Scrap',
          approximateQuantity: '15 - 20 kg',
          actualWeightKg: 18.4,
          ratePerKg: 42.0,
          totalAmount: 772.80,
          vendorName: 'Ramesh Kumar',
          paymentStatus: 'PAID',
        ),
        CollectionRecord(
          id: 'col_100',
          date: DateTime(2026, 9, 24),
          materialName: 'Cardboard & Mixed Paper',
          approximateQuantity: '20 kg',
          actualWeightKg: 20.0,
          ratePerKg: 17.0,
          totalAmount: 340.00,
          vendorName: 'Ramesh Kumar',
          paymentStatus: 'PAID',
        ),
        CollectionRecord(
          id: 'col_099',
          date: DateTime(2026, 9, 10),
          materialName: 'PET Plastic Containers',
          approximateQuantity: '18 - 22 kg',
          actualWeightKg: 20.0,
          ratePerKg: 28.0,
          totalAmount: 560.00,
          vendorName: 'Vijay Scrap Traders',
          paymentStatus: 'PAID',
        ),
      ];
}
