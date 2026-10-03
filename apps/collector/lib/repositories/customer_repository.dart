import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

class CustomerRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  CustomerRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<List<Customer>> getCustomers({String? searchQuery}) async {
    return await _dbService.getCustomers(searchQuery: searchQuery);
  }

  Future<Customer?> getCustomerById(String id) async {
    return await _dbService.getCustomerById(id);
  }

  Future<Customer> saveCustomer(Customer customer) async {
    final toSave = customer.id.isEmpty
        ? customer.copyWith(id: _uuid.v4(), createdAt: DateTime.now())
        : customer;

    await _dbService.insertOrUpdateCustomer(toSave);
    return toSave;
  }
}
