import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class CustomerRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  CustomerRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<List<Customer>> getCustomers({String? searchQuery}) async {
    await syncLoyaltyCustomers();
    return await _dbService.getCustomers(searchQuery: searchQuery);
  }

  Future<Customer?> getCustomerById(String id) async {
    await syncLoyaltyCustomers();
    return await _dbService.getCustomerById(id);
  }

  Future<Customer> saveCustomer(Customer customer) async {
    final toSave = customer.id.isEmpty
        ? customer.copyWith(id: _uuid.v4(), createdAt: DateTime.now())
        : customer;

    await _dbService.insertOrUpdateCustomer(toSave);
    return toSave;
  }

  Future<void> syncLoyaltyCustomers() async {
    try {
      final remote = await RemoteApiService.instance.fetchLoyaltyCustomers();
      if (!remote.success || remote.data == null) return;
      for (final row in remote.data!) {
        final userId = row['userId']?.toString() ?? '';
        if (userId.isEmpty) continue;
        final existing = await _dbService.getCustomerById(userId);
        final completed = (row['completedCount'] as num?)?.toInt() ?? 0;
        final isRegular = row['isRegular'] == true || completed >= 5;
        final lastPurchase = row['lastPurchaseAt'] != null
            ? DateTime.tryParse(row['lastPurchaseAt'].toString())
            : null;
        final lastReminder = row['lastReminderAt'] != null
            ? DateTime.tryParse(row['lastReminderAt'].toString())
            : null;

        final merged = Customer(
          id: userId,
          name: row['userName']?.toString() ??
              existing?.name ??
              'Customer',
          phone: row['userPhone']?.toString() ?? existing?.phone ?? '',
          address: existing?.address ?? 'Pickup area',
          latitude: existing?.latitude ?? 18.5204,
          longitude: existing?.longitude ?? 73.8567,
          totalPickups: completed > (existing?.totalPickups ?? 0)
              ? completed
              : (existing?.totalPickups ?? completed),
          totalWeightKg: existing?.totalWeightKg ?? 0,
          totalPaid: existing?.totalPaid ?? 0,
          lastPickupAt: lastPurchase ?? existing?.lastPickupAt,
          createdAt: existing?.createdAt ?? DateTime.now(),
          isRegular: isRegular || (existing?.isRegular ?? false),
          userPublicId: userId,
          lastReminderAt: lastReminder ?? existing?.lastReminderAt,
          suggestedCadence: row['suggestedCadence']?.toString(),
          daysInactive: (row['daysInactive'] as num?)?.toInt(),
        );
        await _dbService.insertOrUpdateCustomer(merged);
      }
    } catch (_) {}
  }

  Future<String?> sendReminder({
    required String userId,
    required String cadence,
  }) async {
    final result = await RemoteApiService.instance.sendLoyaltyReminder(
      userId: userId,
      cadence: cadence,
    );
    if (!result.success) {
      return result.errorMessage ?? 'Failed to send reminder';
    }
    final existing = await _dbService.getCustomerById(userId);
    if (existing != null) {
      await _dbService.insertOrUpdateCustomer(
        existing.copyWith(lastReminderAt: DateTime.now()),
      );
    }
    return null;
  }
}
