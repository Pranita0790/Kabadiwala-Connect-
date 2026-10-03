class Transaction {
  final String id;
  final String lotId;
  final String recyclerId;
  final double quotedPrice;
  final double finalPrice;
  final String paymentStatus; // 'PENDING', 'RECEIVED'
  final String handoverStatus; // 'PENDING', 'COMPLETED'
  final DateTime createdAt;

  // Compatibility fields/getters
  final String categoryName;
  final double weightKg;

  double get finalAmountPaid => finalPrice;
  String get recyclerName => recyclerId;
  DateTime get transactionDate => createdAt;

  Transaction({
    required this.id,
    required this.lotId,
    String? recyclerId,
    double? quotedPrice,
    required double finalPrice,
    required this.paymentStatus,
    String? handoverStatus,
    DateTime? createdAt,
    String? categoryName,
    double? weightKg,
    String? recyclerName,
    DateTime? transactionDate,
  })  : recyclerId = recyclerId ?? recyclerName ?? 'Formal Recycler',
        quotedPrice = quotedPrice ?? finalPrice,
        finalPrice = finalPrice,
        handoverStatus = handoverStatus ?? 'COMPLETED',
        createdAt = createdAt ?? transactionDate ?? DateTime.now(),
        categoryName = categoryName ?? 'E-Waste Lot',
        weightKg = weightKg ?? 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lot_id': lotId,
      'recycler_id': recyclerId,
      'quoted_price': quotedPrice,
      'final_price': finalPrice,
      'payment_status': paymentStatus,
      'handover_status': handoverStatus,
      'created_at': createdAt.toIso8601String(),
      'category_name': categoryName,
      'weight_kg': weightKg,
      'final_amount_paid': finalPrice,
      'recycler_name': recyclerId,
      'transaction_date': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final finalP = ((map['final_price'] ?? map['final_amount_paid'] ?? 0.0) as num).toDouble();
    final quotedP = ((map['quoted_price'] ?? finalP) as num).toDouble();
    final created = map['created_at'] != null
        ? DateTime.parse(map['created_at'] as String)
        : (map['transaction_date'] != null ? DateTime.parse(map['transaction_date'] as String) : DateTime.now());

    return Transaction(
      id: map['id'] as String,
      lotId: map['lot_id'] as String,
      recyclerId: (map['recycler_id'] ?? map['recycler_name']) as String?,
      quotedPrice: quotedP,
      finalPrice: finalP,
      paymentStatus: (map['payment_status'] as String?) ?? 'PENDING',
      handoverStatus: (map['handover_status'] as String?) ?? 'COMPLETED',
      createdAt: created,
      categoryName: map['category_name'] as String?,
      weightKg: ((map['weight_kg'] ?? 0.0) as num).toDouble(),
    );
  }
}
