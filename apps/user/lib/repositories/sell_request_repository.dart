import 'package:flutter/foundation.dart';
import '../models/sell_request.dart';
import '../models/vendor.dart';

class SellRequestRepository extends ChangeNotifier {
  static final SellRequestRepository _instance = SellRequestRepository._internal();
  factory SellRequestRepository() => _instance;
  SellRequestRepository._internal() {
    _initInitialData();
  }

  final List<SellRequest> _requests = [];

  void _initInitialData() {
    final defaultVendor = Vendor.sampleVendors.first;
    _requests.add(
      SellRequest(
        id: 'req_2001',
        materialName: 'Metal (Iron & Copper Wires)',
        materialCategory: 'Metal',
        approximateQuantity: '15 - 20 kg',
        pickupLocation: 'Flat 302, Sunrise Heights, Kothrud, Pune',
        preferredTime: 'Today, 4:00 PM - 6:00 PM',
        note: 'Scrap kept near balcony store room.',
        vendorId: defaultVendor.id,
        vendorName: defaultVendor.name,
        vendorPhone: defaultVendor.phone,
        ratePerKg: defaultVendor.ratesPerKg['Metal'] ?? 42.0,
        status: 'KABADIWALA_ACCEPTED',
      ),
    );
  }

  List<SellRequest> get requests => List.unmodifiable(_requests);

  SellRequest? get activeRequest {
    try {
      return _requests.firstWhere((r) => r.status != 'PAYMENT_COMPLETED');
    } catch (_) {
      return _requests.isNotEmpty ? _requests.first : null;
    }
  }

  SellRequest createRequest({
    required String materialName,
    required String materialCategory,
    required String approximateQuantity,
    required String pickupLocation,
    required String preferredTime,
    String? note,
    required Vendor vendor,
  }) {
    final rate = vendor.ratesPerKg[materialCategory] ?? vendor.ratesPerKg.values.first;

    final newReq = SellRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      materialName: materialName,
      materialCategory: materialCategory,
      approximateQuantity: approximateQuantity,
      pickupLocation: pickupLocation,
      preferredTime: preferredTime,
      note: note,
      vendorId: vendor.id,
      vendorName: vendor.name,
      vendorPhone: vendor.phone,
      ratePerKg: rate,
      status: 'REQUEST_CREATED',
    );

    _requests.insert(0, newReq);
    notifyListeners();
    return newReq;
  }

  void advanceRequestStatus(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _requests[index];
      String nextStatus;
      double? weight = req.actualWeightKg;
      double? amount = req.finalAmount;

      switch (req.status) {
        case 'REQUEST_CREATED':
          nextStatus = 'KABADIWALA_ACCEPTED';
          break;
        case 'KABADIWALA_ACCEPTED':
          nextStatus = 'PICKUP_SCHEDULED';
          break;
        case 'PICKUP_SCHEDULED':
          nextStatus = 'SCRAP_COLLECTED';
          break;
        case 'SCRAP_COLLECTED':
          nextStatus = 'WEIGHT_RECORDED';
          weight = 18.4; // Measured weight from vendor scale
          break;
        case 'WEIGHT_RECORDED':
          nextStatus = 'AMOUNT_CALCULATED';
          weight = weight ?? 18.4;
          amount = weight * req.ratePerKg;
          break;
        case 'AMOUNT_CALCULATED':
          nextStatus = 'PAYMENT_COMPLETED';
          amount = amount ?? ((weight ?? 18.4) * req.ratePerKg);
          break;
        default:
          nextStatus = req.status;
      }

      _requests[index] = req.copyWith(
        status: nextStatus,
        actualWeightKg: weight,
        finalAmount: amount,
      );
      notifyListeners();
    }
  }

  SellRequest? getRequestById(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
