class SellRequestStatus {
  static const String created = 'REQUEST_CREATED';
  static const String accepted = 'KABADIWALA_ACCEPTED';
  static const String scheduled = 'PICKUP_SCHEDULED';
  static const String collected = 'SCRAP_COLLECTED';
  static const String weightRecorded = 'WEIGHT_RECORDED';
  static const String amountCalculated = 'AMOUNT_CALCULATED';
  static const String completed = 'PAYMENT_COMPLETED';
}

class SellRequest {
  final String id;
  final String materialName;
  final String materialCategory;
  final String approximateQuantity; // e.g. "15 - 20 kg"
  final String pickupLocation;
  final String preferredTime;
  final String? note;
  final String vendorId;
  final String vendorName;
  final String vendorPhone;
  final double ratePerKg;
  final String status;
  final double? actualWeightKg;
  final double? finalAmount;
  final DateTime createdAt;

  final String? userName;
  final String? userPhone;
  final String? pickupAddress;
  final String? preferredTimeSlot;
  final double? estimatedWeightKg;
  final String? description;
  final String? paymentStatus;

  SellRequest({
    required this.id,
    required this.materialName,
    required this.materialCategory,
    String? approximateQuantity,
    String? pickupLocation,
    String? preferredTime,
    this.note,
    String? vendorId,
    String? vendorName,
    String? vendorPhone,
    required this.ratePerKg,
    this.status = 'REQUEST_CREATED',
    this.actualWeightKg,
    this.finalAmount,
    DateTime? createdAt,
    this.userName,
    this.userPhone,
    this.pickupAddress,
    this.preferredTimeSlot,
    this.estimatedWeightKg,
    this.description,
    this.paymentStatus,
  })  : approximateQuantity = approximateQuantity ?? '${estimatedWeightKg ?? 15} kg',
        pickupLocation = pickupLocation ?? pickupAddress ?? 'Home',
        preferredTime = preferredTime ?? preferredTimeSlot ?? 'Flexible',
        vendorId = vendorId ?? 'v1',
        vendorName = vendorName ?? 'Ramesh Kumar',
        vendorPhone = vendorPhone ?? '+91 98765 43210',
        createdAt = createdAt ?? DateTime.now();

  SellRequest copyWith({
    String? id,
    String? materialName,
    String? materialCategory,
    String? approximateQuantity,
    String? pickupLocation,
    String? preferredTime,
    String? note,
    String? vendorId,
    String? vendorName,
    String? vendorPhone,
    double? ratePerKg,
    String? status,
    double? actualWeightKg,
    double? finalAmount,
    DateTime? createdAt,
  }) {
    return SellRequest(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      materialCategory: materialCategory ?? this.materialCategory,
      approximateQuantity: approximateQuantity ?? this.approximateQuantity,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      preferredTime: preferredTime ?? this.preferredTime,
      note: note ?? this.note,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      status: status ?? this.status,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      finalAmount: finalAmount ?? this.finalAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get currentStepIndex {
    switch (status) {
      case 'REQUEST_CREATED':
        return 0;
      case 'KABADIWALA_ACCEPTED':
        return 1;
      case 'PICKUP_SCHEDULED':
        return 2;
      case 'SCRAP_COLLECTED':
        return 3;
      case 'WEIGHT_RECORDED':
        return 4;
      case 'AMOUNT_CALCULATED':
        return 5;
      case 'PAYMENT_COMPLETED':
        return 6;
      default:
        return 0;
    }
  }

  static List<String> get workflowSteps => const [
        'Request Created',
        'Kabadiwala Accepted',
        'Pickup Scheduled',
        'Scrap Collected',
        'Weight Recorded',
        'Amount Calculated',
        'Payment Completed',
      ];
}
