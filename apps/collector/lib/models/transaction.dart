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
    final finalP = ((map['final_price'] ??
            map['finalPrice'] ??
            map['final_amount_paid'] ??
            0.0) as num)
        .toDouble();
    final quotedP =
        ((map['quoted_price'] ?? map['quotedPrice'] ?? finalP) as num)
            .toDouble();
    final createdRaw =
        map['created_at'] ?? map['createdAt'] ?? map['transaction_date'];
    final created = createdRaw != null
        ? DateTime.parse(createdRaw.toString())
        : DateTime.now();

    return Transaction(
      id: (map['id'] ?? map['publicId']).toString(),
      lotId: (map['lot_id'] ?? map['lotId'] ?? '').toString(),
      recyclerId:
          (map['recycler_id'] ?? map['recyclerId'] ?? map['recycler_name'] ?? map['recyclerName'])
              ?.toString(),
      quotedPrice: quotedP,
      finalPrice: finalP,
      paymentStatus:
          (map['payment_status'] ?? map['paymentStatus'] ?? 'PENDING')
              .toString(),
      handoverStatus:
          (map['handover_status'] ?? map['handoverStatus'] ?? 'COMPLETED')
              .toString(),
      createdAt: created,
      categoryName:
          (map['category_name'] ?? map['categoryName']) as String?,
      weightKg:
          ((map['weight_kg'] ?? map['weightKg'] ?? 0.0) as num).toDouble(),
    );
  }
}
