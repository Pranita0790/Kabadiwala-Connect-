import 'package:flutter/foundation.dart';
import '../core/auth/user_auth_controller.dart';
import '../models/sell_request.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';

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

  Future<SellRequest> createRequest({
    required String materialName,
    required String materialCategory,
    required String approximateQuantity,
    required String pickupLocation,
    required String preferredTime,
    String? note,
    required Vendor vendor,
  }) async {
    final rate = vendor.ratesPerKg[materialCategory] ??
        (vendor.ratesPerKg.values.isNotEmpty ? vendor.ratesPerKg.values.first : 0.0);
    final weight = double.tryParse(
          RegExp(r'(\d+(\.\d+)?)').firstMatch(approximateQuantity)?.group(1) ?? '',
        ) ??
        15.0;
    final auth = UserAuthController();

    final remote = await ApiService.instance.createPickupRequest(
      userName: auth.userName.isNotEmpty ? auth.userName : 'Customer',
      userPhone: auth.userPhone,
      pickupAddress: pickupLocation,
      materialCategory: materialCategory,
      materialName: materialName,
      estimatedWeightKg: weight,
      ratePerKg: rate,
      preferredTimeSlot: preferredTime,
      description: note ?? '',
      vendorId: vendor.id,
    );

    final base = remote ??
        SellRequest(
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

    // Always keep selected kabadiwala identity on the local request card.
    final newReq = base.copyWith(
      vendorId: vendor.id,
      vendorName: vendor.name,
      vendorPhone: vendor.phone,
      pickupLocation: pickupLocation,
      preferredTime: preferredTime,
      note: note,
      approximateQuantity: approximateQuantity,
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

  /// Marks a sell request paid using measured/estimated weight.
  void completeWithPayment({
    required String requestId,
    required double weightKg,
    required double amount,
  }) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    _requests[index] = _requests[index].copyWith(
      status: 'PAYMENT_COMPLETED',
      actualWeightKg: weightKg,
      finalAmount: amount,
    );
    notifyListeners();
  }

  /// Pull latest status from backend (collector Accept / Reject / complete).
  Future<SellRequest?> syncRequestFromBackend(String requestId) async {
    final remote = await ApiService.instance.fetchPickupRequest(requestId);
    if (remote == null) return getRequestById(requestId);

    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) {
      _requests.insert(0, remote);
      notifyListeners();
      return remote;
    }

    final local = _requests[index];
    _requests[index] = remote.copyWith(
      vendorName: local.vendorName,
      vendorPhone: local.vendorPhone,
      vendorId: local.vendorId.isNotEmpty ? local.vendorId : remote.vendorId,
      note: remote.note ?? local.note,
    );
    notifyListeners();
    return _requests[index];
  }
}
