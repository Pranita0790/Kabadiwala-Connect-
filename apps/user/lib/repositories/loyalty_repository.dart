import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class LoyaltyRelation {
  final String collectorId;
  final int chooseCount;
  final int completedCount;
  final bool isFavorite;
  final bool isRegular;

  const LoyaltyRelation({
    required this.collectorId,
    this.chooseCount = 0,
    this.completedCount = 0,
    this.isFavorite = false,
    this.isRegular = false,
  });

  factory LoyaltyRelation.fromJson(Map<String, dynamic> json) {
    return LoyaltyRelation(
      collectorId: json['collectorId']?.toString() ?? '',
      chooseCount: (json['chooseCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      isFavorite: json['isFavorite'] == true,
      isRegular: json['isRegular'] == true,
    );
  }
}

class LoyaltyNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? collectorName;
  final DateTime createdAt;
  final bool isRead;

  const LoyaltyNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.collectorName,
    required this.createdAt,
    this.isRead = false,
  });

  factory LoyaltyNotification.fromJson(Map<String, dynamic> json) {
    return LoyaltyNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      title: json['titleEn']?.toString() ??
          json['titleHi']?.toString() ??
          'Notification',
      body: json['bodyEn']?.toString() ??
          json['bodyHi']?.toString() ??
          '',
      collectorName: json['collectorName']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }
}

/// Local + remote favorite / purchase / referral state for the household user.
class LoyaltyRepository extends ChangeNotifier {
  static final LoyaltyRepository _instance = LoyaltyRepository._internal();
  factory LoyaltyRepository() => _instance;
  LoyaltyRepository._internal();

  static const int favoriteThreshold = 5;

  final Map<String, LoyaltyRelation> _relations = {};
  String? _referralCode;
  double _creditsBalance = 0;
  double _referralEarnings = 0;
  List<Map<String, dynamic>> _ledger = [];
  List<LoyaltyNotification> _notifications = [];
  bool _loading = false;

  bool get isLoading => _loading;
  String? get referralCode => _referralCode;
  double get creditsBalance => _creditsBalance;
  double get referralEarnings => _referralEarnings;
  List<Map<String, dynamic>> get ledger => List.unmodifiable(_ledger);
  List<LoyaltyNotification> get notifications =>
      List.unmodifiable(_notifications);
  Set<String> get favoriteIds => _relations.values
      .where((r) => r.isFavorite)
      .map((r) => r.collectorId)
      .toSet();

  String? get preferredFavoriteId {
    LoyaltyRelation? best;
    for (final r in _relations.values) {
      if (!r.isFavorite) continue;
      if (best == null || r.completedCount > best.completedCount) {
        best = r;
      }
    }
    return best?.collectorId;
  }

  bool isFavorite(String collectorId) =>
      _relations[collectorId]?.isFavorite == true;

  int purchaseCount(String collectorId) =>
      _relations[collectorId]?.completedCount ?? 0;

  Future<void> sync() async {
    _loading = true;
    notifyListeners();
    try {
      await ApiService.instance.restoreSession();
      final me = await ApiService.instance.fetchLoyaltyMe();
      if (me != null) {
        _applyMe(me);
      }
      final referral = await ApiService.instance.fetchReferral();
      if (referral != null) {
        _referralCode = referral['referralCode']?.toString() ?? _referralCode;
        _creditsBalance =
            (referral['creditsBalance'] as num?)?.toDouble() ?? _creditsBalance;
        _referralEarnings =
            (referral['referralEarnings'] as num?)?.toDouble() ??
                _referralEarnings;
        if (referral['ledger'] is List) {
          _ledger = (referral['ledger'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      final notifs = await ApiService.instance.fetchLoyaltyNotifications();
      _notifications = notifs
          .map((d) => LoyaltyNotification.fromJson(d.toLoyaltyJson()))
          .toList();
    } catch (e) {
      debugPrint('LoyaltyRepository.sync failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _applyMe(Map<String, dynamic> me) {
    final profile = me['profile'];
    if (profile is Map) {
      _referralCode = profile['referralCode']?.toString() ?? _referralCode;
      _creditsBalance =
          (profile['creditsBalance'] as num?)?.toDouble() ?? _creditsBalance;
      if (profile['ledger'] is List) {
        _ledger = (profile['ledger'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    final relations = me['relations'];
    if (relations is List) {
      _relations.clear();
      for (final item in relations.whereType<Map>()) {
        final r = LoyaltyRelation.fromJson(Map<String, dynamic>.from(item));
        if (r.collectorId.isNotEmpty) {
          _relations[r.collectorId] = r;
        }
      }
    }
    final notifs = me['notifications'];
    if (notifs is List) {
      _notifications = notifs
          .whereType<Map>()
          .map((e) => LoyaltyNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Future<void> recordChoose(String collectorId) async {
    if (collectorId.isEmpty) return;
    final existing = _relations[collectorId];
    _relations[collectorId] = LoyaltyRelation(
      collectorId: collectorId,
      chooseCount: (existing?.chooseCount ?? 0) + 1,
      completedCount: existing?.completedCount ?? 0,
      isFavorite: existing?.isFavorite ?? false,
      isRegular: existing?.isRegular ?? false,
    );
    notifyListeners();
    try {
      await ApiService.instance.postLoyaltyChoose(collectorId);
    } catch (e) {
      debugPrint('recordChoose remote failed: $e');
    }
  }

  /// Call after a completed payment / purchase with this kabadiwala.
  Future<LoyaltyRelation?> recordPurchase({
    required String collectorId,
    required String requestId,
    required double amount,
  }) async {
    if (collectorId.isEmpty) return null;
    final existing = _relations[collectorId];
    final nextCount = (existing?.completedCount ?? 0) + 1;
    final isFavorite = nextCount >= favoriteThreshold;
    final local = LoyaltyRelation(
      collectorId: collectorId,
      chooseCount: existing?.chooseCount ?? 0,
      completedCount: nextCount,
      isFavorite: isFavorite,
      isRegular: isFavorite,
    );
    _relations[collectorId] = local;
    notifyListeners();

    try {
      final remote = await ApiService.instance.postLoyaltyPurchase(
        collectorId: collectorId,
        requestId: requestId,
        amount: amount,
      );
      if (remote != null) {
        final pair = remote['pair'];
        if (pair is Map) {
          final r = LoyaltyRelation.fromJson(Map<String, dynamic>.from(pair));
          _relations[collectorId] = r;
          notifyListeners();
          return r;
        }
      }
    } catch (e) {
      debugPrint('recordPurchase remote failed: $e');
    }
    return local;
  }

  Future<bool> applyReferralCode(String code) async {
    final result = await ApiService.instance.applyReferralCode(code);
    if (result) await sync();
    return result;
  }
}
