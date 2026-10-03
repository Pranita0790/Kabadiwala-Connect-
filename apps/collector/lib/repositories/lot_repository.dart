import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/e_waste_lot.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class LotRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  LotRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Rule: Local-first save.
  /// Assigns a unique UUID v4 primary key, marks status as PENDING_SYNC,
  /// and persists metadata directly to SQLite without network dependency.
  Future<EWasteLot> saveLotLocally({
    required String categoryId,
    required String categoryName,
    required double weightKg,
    required String condition,
    String? imagePath,
    String? notes,
    required double minPrice,
    required double maxPrice,
  }) async {
    final now = DateTime.now();

    final lot = EWasteLot(
      id: _uuid.v4(), // Unique local ID (UUID v4)
      categoryId: categoryId,
      categoryName: categoryName,
      weightKg: weightKg,
      condition: condition,
      imagePath: imagePath,
      notes: notes,
      estimatedMinPrice: minPrice,
      estimatedMaxPrice: maxPrice,
      status: 'CREATED',
      syncStatus: AppConstants.syncPending, // Mark as PENDING_SYNC
      createdAt: now,
      updatedAt: now,
    );

    // Save to local SQLite database
    await _dbService.insertLot(lot);

    // Best-effort push so Recycler Incoming Lots can see it quickly.
    try {
      await SyncService.getInstance().syncPendingRecords();
    } catch (_) {}

    return lot;
  }

  Future<List<EWasteLot>> getLots() async {
    return await _dbService.getAllLots();
  }

  Future<EWasteLot?> getLotById(String id) async {
    return await _dbService.getLot(id);
  }

  Future<void> updateLotStatus(String lotId, String newStatus) async {
    await _dbService.updateLotStatus(lotId, newStatus);
  }
}
