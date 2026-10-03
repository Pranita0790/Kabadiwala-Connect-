import 'package:uuid/uuid.dart';
import '../models/collector_rate.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/session_store.dart';

class CollectorRateRepository {
  final DatabaseService _dbService;
  final SessionStore _sessionStore;
  final Uuid _uuid = const Uuid();

  CollectorRateRepository({
    DatabaseService? dbService,
    SessionStore? sessionStore,
  })  : _dbService = dbService ?? DatabaseService(),
        _sessionStore = sessionStore ?? SessionStore();

  /// Backend publicId of the logged-in collector (used as vendor id in user app).
  Future<String> resolveCollectorId() async {
    final id = await _sessionStore.getBackendUserId();
    if (id != null && id.trim().isNotEmpty) {
      return id.trim();
    }
    return 'default_collector';
  }

  Future<List<CollectorRate>> getRates({String? collectorId}) async {
    final id = collectorId ?? await resolveCollectorId();
    try {
      final remote = await RemoteApiService.instance.fetchCollectorRates(
        collectorId: id,
      );
      if (remote.success && remote.data != null) {
        for (final rate in remote.data!) {
          await _dbService.insertOrUpdateCollectorRate(rate);
        }
      }
    } catch (_) {}

    final own = await _dbService.getCollectorRates(collectorId: id);
    if (own.isNotEmpty || id == 'default_collector') {
      return own;
    }

    // Offline demo rates created before login — migrate them to this collector.
    final legacy = await _dbService.getCollectorRates(
      collectorId: 'default_collector',
    );
    if (legacy.isEmpty) return own;

    final migrated = <CollectorRate>[];
    for (final rate in legacy) {
      final next = rate.copyWith(collectorId: id, updatedAt: DateTime.now());
      await _dbService.insertOrUpdateCollectorRate(next);
      migrated.add(next);
      try {
        await RemoteApiService.instance.uploadCollectorRate(next);
      } catch (_) {}
    }
    return migrated;
  }

  Future<CollectorRate?> getRateById(String id) async {
    return await _dbService.getCollectorRateById(id);
  }

  Future<CollectorRate> saveRate(CollectorRate rate) async {
    final collectorId = rate.collectorId.isNotEmpty &&
            rate.collectorId != 'default_collector'
        ? rate.collectorId
        : await resolveCollectorId();

    final rateToSave = rate.id.isEmpty
        ? rate.copyWith(
            id: _uuid.v4(),
            collectorId: collectorId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : rate.copyWith(
            collectorId: collectorId,
            updatedAt: DateTime.now(),
          );

    await _dbService.insertOrUpdateCollectorRate(rateToSave);
    try {
      await RemoteApiService.instance.uploadCollectorRate(rateToSave);
    } catch (_) {}
    return rateToSave;
  }

  Future<void> deleteRate(String id) async {
    await _dbService.deleteCollectorRate(id);
    try {
      await RemoteApiService.instance.deleteRemoteCollectorRate(id);
    } catch (_) {}
  }
}
