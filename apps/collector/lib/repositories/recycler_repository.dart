import '../models/recycler.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class RecyclerResult {
  final List<Recycler> recyclers;
  final bool isOffline;
  final String? errorMessage;

  RecyclerResult({
    required this.recyclers,
    required this.isOffline,
    this.errorMessage,
  });
}

/// Repository managing e-waste recyclers data and proximity matching.
/// Follows the offline-first architecture with SQLite caching.
class RecyclerRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;

  RecyclerRepository({
    DatabaseService? dbService,
    ApiService? apiService,
    ConnectivityService? connectivityService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _apiService = apiService ?? RemoteApiService.instance,
        _connectivityService = connectivityService ?? ConnectivityService.instance;

  static String normalizeCategoryId(String? input) {
    if (input == null || input.isEmpty || input == 'all' || input == 'E-Waste') {
      return 'all';
    }
    final lower = input.toLowerCase().trim();
    if (lower.contains('pcb') || lower.contains('motherboard')) return 'pcb';
    if (lower.contains('copper') || lower.contains('wire') || lower.contains('तार')) return 'copper_wire';
    if (lower.contains('battery') || lower.contains('batteries') || lower.contains('बैटरी') || lower.contains('बॅटरी')) return 'battery';
    if (lower.contains('display') || lower.contains('monitor') || lower.contains('स्क्रीन')) return 'display';
    if (lower.contains('appliance') || lower.contains('electrical') || lower.contains('heavy')) return 'appliances';
    if (lower.contains('mixed') || lower.contains('मिश्रित')) return 'mixed';
    return lower;
  }

  static bool matchesCategory(Recycler r, String? targetCategory) {
    final norm = normalizeCategoryId(targetCategory);
    if (norm == 'all' || norm == 'mixed' || norm.isEmpty) return true;
    if (r.acceptedCategories.isEmpty ||
        r.acceptedCategories.contains('mixed') ||
        r.acceptedCategories.contains('all')) {
      return true;
    }
    return r.acceptedCategories.any((cat) {
      final normCat = normalizeCategoryId(cat);
      return normCat == norm || normCat == 'mixed' || normCat == 'all';
    });
  }

  Future<RecyclerResult> fetchMatchingRecyclers({
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    final isOnline = await _connectivityService.isConnected();
    final normCategory = normalizeCategoryId(categoryId);
    // forceRefresh kept for call-site compatibility; online always refreshes.
    // ignore: unused_local_variable
    final _ = forceRefresh;

    // Always try the network when online so newly signed-up recyclers appear.
    if (isOnline) {
      try {
        final apiResponse = await _apiService.fetchMatchingRecyclers(
          categoryId: normCategory == 'all' ? null : normCategory,
        );
        if (apiResponse.success &&
            apiResponse.data != null &&
            apiResponse.data!.isNotEmpty) {
          await _dbService.replaceAllRecyclers(apiResponse.data!);
          final ranked = _rankAndFilter(apiResponse.data!, normCategory);
          return RecyclerResult(recyclers: ranked, isOffline: false);
        }
      } catch (_) {
        // Fall through to SQLite / offline cache.
      }
    }

    try {
      List<Recycler> localRecyclers = await _dbService.getRecyclers();

      // First run / empty cache: seed from API mock fallback.
      if (localRecyclers.isEmpty) {
        final apiResponse =
            await _apiService.fetchMatchingRecyclers(categoryId: null);
        if (apiResponse.success &&
            apiResponse.data != null &&
            apiResponse.data!.isNotEmpty) {
          await _dbService.insertRecyclers(apiResponse.data!);
          localRecyclers = apiResponse.data!;
        }
      }

      return RecyclerResult(
        recyclers: _rankAndFilter(localRecyclers, normCategory),
        isOffline: !isOnline,
      );
    } catch (e) {
      return RecyclerResult(
        recyclers: [],
        isOffline: !isOnline,
        errorMessage: e.toString(),
      );
    }
  }

  List<Recycler> _rankAndFilter(List<Recycler> input, String normCategory) {
    var list = List<Recycler>.from(input);
    if (normCategory != 'all' && normCategory.isNotEmpty) {
      list = list.where((r) => matchesCategory(r, normCategory)).toList();
    }
    list.sort((a, b) {
      if (a.isAuthorized != b.isAuthorized) {
        return a.isAuthorized ? -1 : 1;
      }
      // Prefer real (non-demo) recyclers so a signed-up facility appears first.
      if (a.isDemo != b.isDemo) {
        return a.isDemo ? 1 : -1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return list;
  }

  Future<Recycler?> getRecyclerById(String id) async {
    return _dbService.getRecyclerById(id);
  }

  Future<List<Recycler>> getMatchingRecyclers({String? category}) async {
    final res = await fetchMatchingRecyclers(categoryId: category);
    return res.recyclers;
  }

  Future<void> saveRecyclersLocally(List<Recycler> recyclers) async {
    await _dbService.insertRecyclers(recyclers);
  }
}
