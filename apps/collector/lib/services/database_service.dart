import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import '../models/e_waste_lot.dart';
import '../models/handover.dart';
import '../models/price.dart';
import '../models/price_alert.dart';
import '../models/recycler.dart';
import '../models/sync_queue_item.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import '../models/collector_rate.dart';
import '../models/customer.dart';
import '../models/pickup_request.dart';

class DatabaseException implements Exception {
  final String message;
  final dynamic originalError;

  DatabaseException(this.message, [this.originalError]);

  @override
  String toString() => 'DatabaseException: $message ${originalError ?? ""}';
}

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  static Completer<Database>? _initCompleter;
  
  // Custom database factory for testing/overrides
  static DatabaseFactory? _testDatabaseFactory;
  static String? _testDatabasePath;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  static DatabaseService get instance => DatabaseService();

  /// Allows setting a custom DatabaseFactory or path for unit testing (e.g. sqflite_ffi)
  static void setTestFactory(DatabaseFactory factory, {String? customPath}) {
    _testDatabaseFactory = factory;
    _testDatabasePath = customPath;
    _database = null;
    _initCompleter = null;
    _instance = DatabaseService._internal();
  }

  /// Reset database instance (useful for test isolation or closing DB)
  static Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    _initCompleter = null;
  }

  /// Safe, centralized, idempotent Database initialization
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _database = db;
      _initCompleter!.complete(db);
      return db;
    } catch (e, stack) {
      _initCompleter!.completeError(e, stack);
      _initCompleter = null;
      throw DatabaseException('Failed to initialize local database', e);
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final String path;
      if (_testDatabasePath != null) {
        path = _testDatabasePath!;
      } else {
        final dbPath = await getDatabasesPath();
        path = join(dbPath, AppConstants.dbName);
      }

      final factory = _testDatabaseFactory ?? databaseFactory;

      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: AppConstants.dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: _onOpen,
        ),
      );
    } catch (e) {
      throw DatabaseException('Database open failed', e);
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _createTables(db);
  }

  static Future<void> _onOpen(Database db) async {
    await _createTables(db);
  }

  static Future<void> _createTables(Database db) async {
    // 1. LOTS Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableLots} (
        id TEXT PRIMARY KEY,
        image_path TEXT,
        category TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        weight REAL NOT NULL,
        weight_kg REAL,
        condition TEXT NOT NULL,
        notes TEXT,
        estimated_min_price REAL NOT NULL,
        estimated_max_price REAL NOT NULL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. PRICES Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablePrices} (
        id TEXT PRIMARY KEY,
        material TEXT NOT NULL,
        min_price REAL NOT NULL,
        max_price REAL NOT NULL,
        unit TEXT NOT NULL,
        location TEXT NOT NULL,
        source TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        category_id TEXT,
        category_name_en TEXT,
        category_name_hi TEXT,
        category_name_mr TEXT,
        min_price_per_unit REAL,
        max_price_per_unit REAL,
        icon_asset TEXT,
        last_updated TEXT
      )
    ''');

    // 3. TRANSACTIONS Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableTransactions} (
        id TEXT PRIMARY KEY,
        lot_id TEXT NOT NULL,
        recycler_id TEXT NOT NULL,
        quoted_price REAL NOT NULL,
        final_price REAL NOT NULL,
        payment_status TEXT NOT NULL,
        handover_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        category_name TEXT,
        weight_kg REAL,
        final_amount_paid REAL,
        recycler_name TEXT,
        transaction_date TEXT
      )
    ''');

    // 4. SYNC_QUEUE Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableSyncQueue} (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 5. SETTINGS Table (for persisted user preferences like language)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableSettings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 6. RECYCLERS Table (Member 3)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableRecyclers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        accepted_categories TEXT NOT NULL,
        distance_km REAL NOT NULL,
        is_authorized INTEGER NOT NULL,
        rating REAL NOT NULL,
        contact_phone TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        indicative_price REAL,
        unit TEXT NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 7. HANDOVERS Table (Member 3)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableHandovers} (
        id TEXT PRIMARY KEY,
        lot_id TEXT NOT NULL,
        recycler_id TEXT NOT NULL,
        recycler_name TEXT NOT NULL,
        material_category TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        agreed_amount REAL NOT NULL,
        status TEXT NOT NULL,
        qr_payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        confirmed_at TEXT,
        sync_status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 8. NOTIFICATIONS Table (Member 3)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableNotifications} (
        id TEXT PRIMARY KEY,
        title_en TEXT NOT NULL,
        title_hi TEXT NOT NULL,
        title_mr TEXT NOT NULL,
        body_en TEXT NOT NULL,
        body_hi TEXT NOT NULL,
        body_mr TEXT NOT NULL,
        type TEXT NOT NULL,
        related_id TEXT,
        timestamp TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_demo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 9. PRICE_ALERTS Table (Member 3)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablePriceAlerts} (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        target_price REAL NOT NULL,
        unit TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        triggered_at TEXT
      )
    ''');

    // 10. USERS Table (Auth & Profile)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableUsers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        password_hash TEXT,
        city TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'collector',
        photo_path TEXT,
        is_profile_complete INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Backward-compatible column migration if table existed
    try {
      await db.execute('ALTER TABLE ${AppConstants.tableUsers} ADD COLUMN password_hash TEXT');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCollectorRates} (
        id TEXT PRIMARY KEY,
        collector_id TEXT NOT NULL,
        material_category TEXT NOT NULL,
        material_name TEXT NOT NULL,
        rate_per_kg REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'kg',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tablePickupRequests} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        user_phone TEXT NOT NULL,
        pickup_address TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        preferred_time_slot TEXT NOT NULL,
        material_category TEXT NOT NULL,
        material_name TEXT NOT NULL,
        estimated_weight_kg REAL NOT NULL,
        rate_per_kg REAL NOT NULL,
        photo_url TEXT,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'PENDING',
        actual_weight_kg REAL,
        final_amount REAL,
        payment_method TEXT,
        payment_status TEXT NOT NULL DEFAULT 'PENDING',
        collector_id TEXT NOT NULL DEFAULT 'default_collector',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tableCustomers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        total_pickups INTEGER NOT NULL DEFAULT 0,
        total_weight_kg REAL NOT NULL DEFAULT 0.0,
        total_paid REAL NOT NULL DEFAULT 0.0,
        last_pickup_at TEXT,
        created_at TEXT NOT NULL,
        is_regular INTEGER NOT NULL DEFAULT 0,
        user_public_id TEXT,
        last_reminder_at TEXT
      )
    ''');

    try {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN is_regular INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN user_public_id TEXT',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN last_reminder_at TEXT',
      );
    } catch (_) {}

    await _seedDemoUserKabadiwalaData(db);
  }

  // ==========================================
  // LOTS OPERATIONS
  // ==========================================

  /// Inserts a lot atomically with a SYNC_QUEUE entry using a batch
  Future<void> insertLot(EWasteLot lot) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.insert(
        AppConstants.tableLots,
        lot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final syncItem = SyncQueueItem(
        id: 'sync_lot_${lot.id}',
        entityType: 'LOT',
        entityId: lot.id,
        operation: 'CREATE',
        createdAt: DateTime.now(),
      );

      batch.insert(
        AppConstants.tableSyncQueue,
        syncItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to insert lot into database', e);
    }
  }

  Future<EWasteLot?> getLot(String id) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLots,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return EWasteLot.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to fetch lot with id: $id', e);
    }
  }

  Future<List<EWasteLot>> getLots() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLots,
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => EWasteLot.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch lots', e);
    }
  }

  // Alias for backward compatibility
  Future<List<EWasteLot>> getAllLots() => getLots();

  /// Updates a lot and queues an UPDATE sync item inside a batch
  Future<void> updateLot(EWasteLot lot) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.update(
        AppConstants.tableLots,
        lot.toMap(),
        where: 'id = ?',
        whereArgs: [lot.id],
      );

      final syncItem = SyncQueueItem(
        id: 'sync_update_lot_${lot.id}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'LOT',
        entityId: lot.id,
        operation: 'UPDATE',
        createdAt: DateTime.now(),
      );

      batch.insert(
        AppConstants.tableSyncQueue,
        syncItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to update lot in database', e);
    }
  }

  /// Updates a lot's status directly in the database
  Future<void> updateLotStatus(String lotId, String newStatus) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableLots,
        {
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [lotId],
      );
    } catch (e) {
      throw DatabaseException('Failed to update lot status', e);
    }
  }

  // ==========================================
  // PRICES OPERATIONS
  // ==========================================

  Future<void> insertPrice(Price price) async {
    try {
      final db = await database;
      await db.insert(
        AppConstants.tablePrices,
        price.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to insert price', e);
    }
  }

  Future<List<Price>> getPrices() async {
    try {
      final db = await database;
      final maps = await db.query(AppConstants.tablePrices);
      return maps.map((m) => Price.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch prices', e);
    }
  }

  // Alias for backward compatibility
  Future<List<Price>> getAllPrices() => getPrices();

  // ==========================================
  // TRANSACTIONS OPERATIONS
  // ==========================================

  Future<void> insertTransaction(Transaction tx) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.insert(
        AppConstants.tableTransactions,
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final syncItem = SyncQueueItem(
        id: 'sync_tx_${tx.id}',
        entityType: 'TRANSACTION',
        entityId: tx.id,
        operation: 'CREATE',
        createdAt: DateTime.now(),
      );

      batch.insert(
        AppConstants.tableSyncQueue,
        syncItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to insert transaction', e);
    }
  }

  Future<List<Transaction>> getTransactions() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableTransactions,
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => Transaction.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch transactions', e);
    }
  }

  /// Removes specific transaction rows (used to clear old mock demo earnings).
  Future<void> deleteTransactionsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        AppConstants.tableTransactions,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      throw DatabaseException('Failed to delete transactions', e);
    }
  }

  // Alias for backward compatibility
  Future<List<Transaction>> getAllTransactions() => getTransactions();

  // ==========================================
  // SYNC QUEUE OPERATIONS
  // ==========================================

  Future<void> addToSyncQueue(SyncQueueItem item) async {
    try {
      final db = await database;
      await db.insert(
        AppConstants.tableSyncQueue,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to add item to sync queue', e);
    }
  }

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableSyncQueue,
        orderBy: 'created_at ASC',
      );
      return maps.map((m) => SyncQueueItem.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch pending sync items', e);
    }
  }

  Future<List<EWasteLot>> getPendingSyncLots() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLots,
        where: 'sync_status = ? OR sync_status = ? OR sync_status = ?',
        whereArgs: [AppConstants.syncPending, AppConstants.syncFailed, AppConstants.syncSyncing],
      );
      return maps.map((m) => EWasteLot.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch pending sync lots', e);
    }
  }

  Future<void> markAsSynced(String lotId) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.update(
        AppConstants.tableLots,
        {
          'sync_status': AppConstants.syncSynced,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [lotId],
      );

      batch.delete(
        AppConstants.tableSyncQueue,
        where: 'entity_id = ?',
        whereArgs: [lotId],
      );
      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to mark entity as synced: $lotId', e);
    }
  }

  Future<void> markAsSyncFailed(String lotId, {String? error}) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.update(
        AppConstants.tableLots,
        {
          'sync_status': AppConstants.syncFailed,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [lotId],
      );

      batch.rawUpdate(
        'UPDATE ${AppConstants.tableSyncQueue} SET retry_count = retry_count + 1 WHERE entity_id = ?',
        [lotId],
      );
      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to mark entity sync failed: $lotId', e);
    }
  }

  Future<void> updateSyncStatus(String lotId, String status) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableLots,
        {
          'sync_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [lotId],
      );
    } catch (e) {
      throw DatabaseException('Failed to update sync status', e);
    }
  }

  // ==========================================
  // SETTINGS / PREFERENCES OPERATIONS
  // ==========================================

  Future<void> saveSetting(String key, String value) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableSettings} (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert(
        AppConstants.tableSettings,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to save setting: $key', e);
    }
  }

  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableSettings} (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      final maps = await db.query(
        AppConstants.tableSettings,
        where: 'key = ?',
        whereArgs: [key],
      );
      if (maps.isEmpty) return null;
      return maps.first['value'] as String?;
    } catch (e) {
      throw DatabaseException('Failed to fetch setting: $key', e);
    }
  }

  Future<void> saveLanguagePreference(String languageCode) async {
    await saveSetting('preferred_language', languageCode);
  }

  Future<String> getLanguagePreference({String defaultLanguage = 'en'}) async {
    final lang = await getSetting('preferred_language');
    return lang ?? defaultLanguage;
  }

  // ==========================================
  // RECYCLERS OPERATIONS (Member 3)
  // ==========================================

  Future<void> insertRecyclers(List<Recycler> recyclers) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final r in recyclers) {
        batch.insert(
          AppConstants.tableRecyclers,
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to insert recyclers into SQLite', e);
    }
  }

  /// Replace the whole recycler cache so stale demo rows cannot hide live ORG.
  Future<void> replaceAllRecyclers(List<Recycler> recyclers) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(AppConstants.tableRecyclers);
        final batch = txn.batch();
        for (final r in recyclers) {
          batch.insert(AppConstants.tableRecyclers, r.toMap());
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw DatabaseException('Failed to replace recyclers in SQLite', e);
    }
  }

  Future<List<Recycler>> getRecyclers() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableRecyclers,
        orderBy: 'distance_km ASC',
      );
      return maps.map((m) => Recycler.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch recyclers', e);
    }
  }

  Future<List<Recycler>> getMatchingRecyclers(String categoryId) async {
    try {
      final all = await getRecyclers();
      if (all.isEmpty) return [];
      return all.where((r) =>
          r.acceptedCategories.contains(categoryId) ||
          r.acceptedCategories.contains('mixed') ||
          r.acceptedCategories.isEmpty).toList();
    } catch (e) {
      throw DatabaseException('Failed to query matching recyclers for category $categoryId', e);
    }
  }

  Future<Recycler?> getRecyclerById(String id) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableRecyclers,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return Recycler.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to fetch recycler $id', e);
    }
  }

  // ==========================================
  // HANDOVER OPERATIONS (Member 3)
  // ==========================================

  Future<void> insertHandover(Handover handover) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.insert(
        AppConstants.tableHandovers,
        handover.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final syncItem = SyncQueueItem(
        id: 'sync_handover_${handover.id}',
        entityType: 'HANDOVER',
        entityId: handover.id,
        operation: 'CREATE',
        createdAt: DateTime.now(),
      );

      batch.insert(
        AppConstants.tableSyncQueue,
        syncItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to insert handover into SQLite', e);
    }
  }

  Future<List<Handover>> getHandovers() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableHandovers,
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => Handover.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch handovers', e);
    }
  }

  Future<Handover?> getHandoverById(String id) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableHandovers,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return Handover.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to fetch handover $id', e);
    }
  }

  Future<List<Handover>> getPendingSyncHandovers() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableHandovers,
        where: 'sync_status = ? OR sync_status = ?',
        whereArgs: [AppConstants.syncPending, AppConstants.syncFailed],
      );
      return maps.map((m) => Handover.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch pending sync handovers', e);
    }
  }

  Future<void> updateHandoverSyncStatus(
    String id,
    String syncStatus, {
    int? retryCount,
  }) async {
    try {
      final db = await database;
      final values = <String, dynamic>{
        'sync_status': syncStatus,
      };
      if (retryCount != null) {
        values['retry_count'] = retryCount;
      }
      await db.update(
        AppConstants.tableHandovers,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update handover sync status for $id', e);
    }
  }

  Future<void> updateHandoverStatus(
    String id,
    String status, {
    DateTime? confirmedAt,
  }) async {
    try {
      final db = await database;
      final values = <String, dynamic>{
        'status': status,
      };
      if (confirmedAt != null) {
        values['confirmed_at'] = confirmedAt.toIso8601String();
      }
      await db.update(
        AppConstants.tableHandovers,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update handover status for $id', e);
    }
  }

  // ==========================================
  // NOTIFICATIONS OPERATIONS (Member 3)
  // ==========================================

  Future<void> insertNotification(AppNotification notification) async {
    try {
      final db = await database;
      await db.insert(
        AppConstants.tableNotifications,
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to insert notification into SQLite', e);
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableNotifications,
        orderBy: 'timestamp DESC',
      );
      return maps.map((m) => AppNotification.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch notifications', e);
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.tableNotifications} WHERE is_read = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw DatabaseException('Failed to fetch unread notification count', e);
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableNotifications,
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to mark notification $id as read', e);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableNotifications,
        {'is_read': 1},
      );
    } catch (e) {
      throw DatabaseException('Failed to mark all notifications as read', e);
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final db = await database;
      await db.delete(AppConstants.tableNotifications);
    } catch (e) {
      throw DatabaseException('Failed to clear notifications', e);
    }
  }

  // ==========================================
  // PRICE ALERTS OPERATIONS (Member 3)
  // ==========================================

  Future<void> insertPriceAlert(PriceAlert alert) async {
    try {
      final db = await database;
      await db.insert(
        AppConstants.tablePriceAlerts,
        alert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to insert price alert into SQLite', e);
    }
  }

  Future<List<PriceAlert>> getPriceAlerts() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tablePriceAlerts,
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => PriceAlert.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch price alerts', e);
    }
  }

  Future<List<PriceAlert>> getActivePriceAlerts() async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tablePriceAlerts,
        where: 'is_active = 1',
        orderBy: 'created_at DESC',
      );
      return maps.map((m) => PriceAlert.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch active price alerts', e);
    }
  }

  Future<void> updatePriceAlertTriggered(String id, DateTime triggeredAt) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tablePriceAlerts,
        {
          'triggered_at': triggeredAt.toIso8601String(),
          'is_active': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update price alert triggered status for $id', e);
    }
  }

  Future<void> deletePriceAlert(String id) async {
    try {
      final db = await database;
      await db.delete(
        AppConstants.tablePriceAlerts,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to delete price alert $id', e);
    }
  }

  // ==========================================
  // USER / AUTH OPERATIONS
  // ==========================================

  Future<void> saveUser(UserProfile user) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableUsers} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone_number TEXT NOT NULL,
          city TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'collector',
          photo_path TEXT,
          is_profile_complete INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.insert(
        AppConstants.tableUsers,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Failed to save user profile: ${user.id}', e);
    }
  }

  Future<UserProfile?> getUser(String id) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableUsers} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone_number TEXT NOT NULL,
          city TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'collector',
          photo_path TEXT,
          is_profile_complete INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      final maps = await db.query(
        AppConstants.tableUsers,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return UserProfile.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to fetch user: $id', e);
    }
  }

  Future<UserProfile?> getUserByPhone(String phoneNumber) async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.tableUsers} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone_number TEXT NOT NULL,
          city TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'collector',
          photo_path TEXT,
          is_profile_complete INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Clean phone number for resilient match
      final clean = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final maps = await db.query(AppConstants.tableUsers);
      for (final row in maps) {
        final rowPhone = (row['phone_number'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (rowPhone == clean || (clean.length == 10 && rowPhone.endsWith(clean)) || (rowPhone.length == 10 && clean.endsWith(rowPhone))) {
          return UserProfile.fromMap(row);
        }
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to fetch user by phone: $phoneNumber', e);
    }
  }

  Future<UserProfile?> getCurrentUser() async {
    try {
      final currentUserId = await getSetting('current_user_id');
      if (currentUserId != null && currentUserId.isNotEmpty) {
        return await getUser(currentUserId);
      }
      return null;
    } catch (e) {
      throw DatabaseException('Failed to fetch current user', e);
    }
  }

  Future<void> setCurrentUserId(String? userId) async {
    try {
      if (userId == null) {
        await saveSetting('current_user_id', '');
      } else {
        await saveSetting('current_user_id', userId);
      }
    } catch (e) {
      throw DatabaseException('Failed to set current user ID', e);
    }
  }

  Future<void> clearAuthSession() async {
    await setCurrentUserId(null);
  }

  Future<void> deleteUser(String id) async {
    try {
      final db = await database;
      await db.delete(
        AppConstants.tableUsers,
        where: 'id = ?',
        whereArgs: [id],
      );
      final currentUserId = await getSetting('current_user_id');
      if (currentUserId == id) {
        await clearAuthSession();
      }
    } catch (e) {
      throw DatabaseException('Failed to delete user: $id', e);
    }
  }

  static Future<void> _seedDemoUserKabadiwalaData(Database db) async {
    final countRates = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppConstants.tableCollectorRates}'),
    );
    if (countRates == 0) {
      final now = DateTime.now().toIso8601String();
      final demoRates = [
        {
          'id': 'rate_1',
          'collector_id': 'default_collector',
          'material_category': 'E-Waste',
          'material_name': 'Motherboards & Circuit Boards',
          'rate_per_kg': 120.0,
          'unit': 'kg',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        },
        {
          'id': 'rate_2',
          'collector_id': 'default_collector',
          'material_category': 'Metals',
          'material_name': 'Copper Wire & Heavy Metals',
          'rate_per_kg': 450.0,
          'unit': 'kg',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        },
        {
          'id': 'rate_3',
          'collector_id': 'default_collector',
          'material_category': 'Batteries',
          'material_name': 'Lithium-Ion Batteries',
          'rate_per_kg': 150.0,
          'unit': 'kg',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        },
      ];
      for (final r in demoRates) {
        await db.insert(AppConstants.tableCollectorRates, r, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    final countCust = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppConstants.tableCustomers}'),
    );
    if (countCust == 0) {
      final now = DateTime.now().toIso8601String();
      final demoCusts = [
        {
          'id': 'cust_1',
          'name': 'Aniket Sharma',
          'phone': '+91 98234 56789',
          'address': 'Flat 402, Green Valley Apts, Kothrud, Pune',
          'latitude': 18.5074,
          'longitude': 73.8077,
          'total_pickups': 3,
          'total_weight_kg': 24.5,
          'total_paid': 2850.0,
          'last_pickup_at': now,
          'created_at': now,
        },
        {
          'id': 'cust_2',
          'name': 'Priya Deshmukh',
          'phone': '+91 98112 34567',
          'address': 'Plot 12, Baner Pashan Link Rd, Pune',
          'latitude': 18.5590,
          'longitude': 73.7868,
          'total_pickups': 1,
          'total_weight_kg': 8.0,
          'total_paid': 680.0,
          'last_pickup_at': now,
          'created_at': now,
        },
      ];
      for (final c in demoCusts) {
        await db.insert(AppConstants.tableCustomers, c, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    final countReqs = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppConstants.tablePickupRequests}'),
    );
    if (countReqs == 0) {
      final now = DateTime.now().toIso8601String();
      final demoReqs = [
        {
          'id': 'req_101',
          'user_id': 'cust_1',
          'user_name': 'Aniket Sharma',
          'user_phone': '+91 98234 56789',
          'pickup_address': 'Flat 402, Green Valley Apts, Kothrud, Pune',
          'latitude': 18.5074,
          'longitude': 73.8077,
          'preferred_time_slot': 'Today, 4:00 PM - 6:00 PM',
          'material_category': 'E-Waste',
          'material_name': 'Motherboards & Circuit Boards',
          'estimated_weight_kg': 5.0,
          'rate_per_kg': 120.0,
          'description': 'Old CPU circuit boards and desktop power supplies.',
          'status': 'PENDING',
          'payment_status': 'PENDING',
          'collector_id': 'default_collector',
          'created_at': now,
          'updated_at': now,
        },
        {
          'id': 'req_102',
          'user_id': 'cust_2',
          'user_name': 'Priya Deshmukh',
          'user_phone': '+91 98112 34567',
          'pickup_address': 'Plot 12, Baner Pashan Link Rd, Pune',
          'latitude': 18.5590,
          'longitude': 73.7868,
          'preferred_time_slot': 'Tomorrow, 10:00 AM - 12:00 PM',
          'material_category': 'Metals',
          'material_name': 'Copper Wire & Heavy Metals',
          'estimated_weight_kg': 8.0,
          'rate_per_kg': 450.0,
          'description': 'Stripped copper wire bundle from electrical renovation.',
          'status': 'ACCEPTED',
          'payment_status': 'PENDING',
          'collector_id': 'default_collector',
          'created_at': now,
          'updated_at': now,
        },
      ];
      for (final req in demoReqs) {
        await db.insert(AppConstants.tablePickupRequests, req, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<List<CollectorRate>> getCollectorRates({String collectorId = 'default_collector'}) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCollectorRates,
      where: 'collector_id = ? AND is_active = 1',
      whereArgs: [collectorId],
      orderBy: 'material_category ASC, material_name ASC',
    );
    return maps.map((m) => CollectorRate.fromMap(m)).toList();
  }

  Future<CollectorRate?> getCollectorRateById(String id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCollectorRates,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return CollectorRate.fromMap(maps.first);
    return null;
  }

  Future<void> insertOrUpdateCollectorRate(CollectorRate rate) async {
    final db = await database;
    await db.insert(
      AppConstants.tableCollectorRates,
      rate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCollectorRate(String id) async {
    final db = await database;
    await db.update(
      AppConstants.tableCollectorRates,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PickupRequest>> getPickupRequests({String? status}) async {
    final db = await database;
    final String? where = status != null && status.isNotEmpty ? 'status = ?' : null;
    final List<Object?>? whereArgs =
        status != null && status.isNotEmpty ? [status] : null;
    final maps = await db.query(
      AppConstants.tablePickupRequests,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => PickupRequest.fromMap(m)).toList();
  }

  Future<PickupRequest?> getPickupRequestById(String id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tablePickupRequests,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return PickupRequest.fromMap(maps.first);
    return null;
  }

  Future<void> insertOrUpdatePickupRequest(PickupRequest request) async {
    final db = await database;
    await db.insert(
      AppConstants.tablePickupRequests,
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Customer>> getCustomers({String? searchQuery}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = '%${searchQuery.trim()}%';
      maps = await db.query(
        AppConstants.tableCustomers,
        where: 'name LIKE ? OR phone LIKE ? OR address LIKE ?',
        whereArgs: [query, query, query],
        orderBy: 'total_paid DESC',
      );
    } else {
      maps = await db.query(
        AppConstants.tableCustomers,
        orderBy: 'total_paid DESC',
      );
    }
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Customer.fromMap(maps.first);
    return null;
  }

  Future<void> insertOrUpdateCustomer(Customer customer) async {
    final db = await database;
    await db.insert(
      AppConstants.tableCustomers,
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns true when the customer newly crossed the regular threshold (≥5).
  Future<bool> updateCustomerStats({
    required String customerId,
    required double addedWeightKg,
    required double addedAmountPaid,
  }) async {
    final existing = await getCustomerById(customerId);
    if (existing != null) {
      final nextPickups = existing.totalPickups + 1;
      final becameRegular = !existing.isRegular && nextPickups >= 5;
      await insertOrUpdateCustomer(
        existing.copyWith(
          totalPickups: nextPickups,
          totalWeightKg: existing.totalWeightKg + addedWeightKg,
          totalPaid: existing.totalPaid + addedAmountPaid,
          lastPickupAt: DateTime.now(),
          isRegular: nextPickups >= 5,
        ),
      );
      return becameRegular;
    }

    await insertOrUpdateCustomer(
      Customer(
        id: customerId,
        name: 'Customer ($customerId)',
        phone: '',
        address: 'Pickup Location',
        totalPickups: 1,
        totalWeightKg: addedWeightKg,
        totalPaid: addedAmountPaid,
        lastPickupAt: DateTime.now(),
        isRegular: false,
        userPublicId: customerId,
      ),
    );
    return false;
  }
}
