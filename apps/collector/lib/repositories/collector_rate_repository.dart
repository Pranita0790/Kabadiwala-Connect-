import 'package:uuid/uuid.dart';
import '../models/collector_rate.dart';
import '../services/database_service.dart';

class CollectorRateRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  CollectorRateRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<List<CollectorRate>> getRates({String collectorId = 'default_collector'}) async {
    return await _dbService.getCollectorRates(collectorId: collectorId);
  }

  Future<CollectorRate?> getRateById(String id) async {
    return await _dbService.getCollectorRateById(id);
  }

  Future<CollectorRate> saveRate(CollectorRate rate) async {
    final rateToSave = rate.id.isEmpty
        ? rate.copyWith(
            id: _uuid.v4(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : rate.copyWith(updatedAt: DateTime.now());

    await _dbService.insertOrUpdateCollectorRate(rateToSave);
    return rateToSave;
  }

  Future<void> deleteRate(String id) async {
    await _dbService.deleteCollectorRate(id);
  }
}
