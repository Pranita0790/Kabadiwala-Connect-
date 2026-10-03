class SellRequest {
  final String id;
  final String userId;
  final String kabadiwalaId;
  final String kabadiwalaName;
  final String materialId;
  final String materialName;
  final double quantityKg;
  final String pickupLocation;
  final DateTime preferredPickupTime;
  final String notes;
  final String status; // PENDING, ACCEPTED, REJECTED, PICKED_UP, COMPLETED
  final DateTime createdAt;
  final DateTime updatedAt;

  SellRequest({
    required this.id,
    required this.userId,
    required this.kabadiwalaId,
    required this.kabadiwalaName,
    required this.materialId,
    required this.materialName,
    required this.quantityKg,
    required this.pickupLocation,
    required this.preferredPickupTime,
    this.notes = '',
    this.status = 'PENDING',
    required this.createdAt,
    required this.updatedAt,
  });
}
