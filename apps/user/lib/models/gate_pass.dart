class GatePass {
  final String passId;
  final String pinCode;
  final String collectorName;
  final String collectorPhone;
  final String vehicleNumber;
  final String residentName;
  final String residentPhone;
  final String societyAddress;
  final String entryDate;
  final String timeWindow;
  final String status; // 'ACTIVE', 'USED', 'EXPIRED'
  final DateTime createdAt;

  GatePass({
    required this.passId,
    required this.pinCode,
    required this.collectorName,
    required this.collectorPhone,
    required this.vehicleNumber,
    required this.residentName,
    required this.residentPhone,
    required this.societyAddress,
    required this.entryDate,
    required this.timeWindow,
    this.status = 'ACTIVE',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get whatsappShareText {
    return '''🔒 *KABADIWALA CONNECT - SECURITY GATE PASS*
----------------------------------------
*Pass ID:* $passId
*Security Verification PIN:* $pinCode
*Collector Name:* $collectorName
*Collector Phone:* $collectorPhone
*Vehicle / Cart No:* $vehicleNumber

*Resident Name:* $residentName
*Address:* $societyAddress
*Entry Window:* $entryDate ($timeWindow)
*Status:* $status

ℹ️ _Security Guard: Please verify PIN $pinCode on arrival to allow entry for scrap pickup._''';
  }
}
