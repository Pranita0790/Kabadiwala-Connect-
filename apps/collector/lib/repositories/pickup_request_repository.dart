import 'package:uuid/uuid.dart';
import '../models/pickup_request.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class PickupRequestRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  PickupRequestRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<List<PickupRequest>> getAllRequests({String? status}) async {
    try {
      final remote = await RemoteApiService.instance.fetchPickupRequests(status: status);
      if (remote.success && remote.data != null) {
        for (final request in remote.data!) {
          await _dbService.insertOrUpdatePickupRequest(request);
        }
      }
    } catch (_) {}
    return await _dbService.getPickupRequests(status: status);
  }

  Future<PickupRequest?> getRequestById(String id) async {
    return await _dbService.getPickupRequestById(id);
  }

  Future<PickupRequest> createRequest(PickupRequest request) async {
    final newRequest = request.id.isEmpty
        ? request.copyWith(
            id: _uuid.v4(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : request;

    await _dbService.insertOrUpdatePickupRequest(newRequest);
    return newRequest;
  }

  Future<PickupRequest> updateRequestStatus(String id, String newStatus) async {
    final existing = await getRequestById(id);
    if (existing == null) {
      throw Exception('Pickup request not found: $id');
    }

    final updated = existing.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
      completedAt: newStatus == 'COMPLETED' ? DateTime.now() : existing.completedAt,
    );

    await _dbService.insertOrUpdatePickupRequest(updated);
    try {
      await RemoteApiService.instance.patchPickupRequestStatus(id, newStatus);
    } catch (_) {}
    return updated;
  }

  Future<PickupRequest> completeCollection({
    required String requestId,
    required double actualWeightKg,
    required String paymentMethod,
  }) async {
    final existing = await getRequestById(requestId);
    if (existing == null) {
      throw Exception('Pickup request not found: $requestId');
    }

    // Explicit Rule: Final amount MUST be actual_weight_kg * rate_per_kg
    final finalAmount = actualWeightKg * existing.ratePerKg;
    final completed = existing.copyWith(
      actualWeightKg: actualWeightKg,
      finalAmount: finalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: 'PAID',
      status: 'COMPLETED',
      updatedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );

    await _dbService.insertOrUpdatePickupRequest(completed);

    try {
      await RemoteApiService.instance.completePickupRequest(
        id: requestId,
        actualWeightKg: actualWeightKg,
        paymentMethod: paymentMethod,
      );
    } catch (_) {}

    // Update customer statistics when collection completes
    final becameRegular = await _dbService.updateCustomerStats(
      customerId: existing.userId,
      addedWeightKg: actualWeightKg,
      addedAmountPaid: finalAmount,
    );
    if (becameRegular) {
      try {
        await NotificationService.instance.notifyRegularCustomer(
          customerName: existing.userName,
          customerId: existing.userId,
        );
      } catch (_) {}
    }

    return completed;
  }
}
