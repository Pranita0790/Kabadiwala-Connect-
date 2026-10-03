import 'package:flutter/foundation.dart';
import '../models/material_item.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import 'loyalty_repository.dart';

class VendorRepository extends ChangeNotifier {
  static final VendorRepository _instance = VendorRepository._internal();
  factory VendorRepository() => _instance;
  VendorRepository._internal();

  final List<Vendor> _vendors = List.from(Vendor.sampleVendors);
  bool _loading = false;
  String? _lastError;

  List<Vendor> get allVendors => List.unmodifiable(_vendors);
  bool get isLoading => _loading;
  String? get lastError => _lastError;

  static List<String> get materialFilters =>
      MaterialItem.defaultMaterials.map((m) => m.category).toList();

  Vendor? get connectedVendor {
    final favoriteId = LoyaltyRepository().preferredFavoriteId;
    if (favoriteId != null) {
      try {
        return _vendors.firstWhere((v) => v.id == favoriteId);
      } catch (_) {}
    }
    try {
      return _vendors.firstWhere((v) => v.isConnected);
    } catch (_) {
      return _vendors.isNotEmpty ? _vendors.first : null;
    }
  }

  List<Vendor> getNearbyVendors({String? searchQuery, String? materialFilter}) {
    final loyalty = LoyaltyRepository();
    final filtered = _vendors.where((v) {
      final q = searchQuery?.trim().toLowerCase() ?? '';
      final matchesSearch = q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.location.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q);

      final filter = materialFilter?.trim() ?? '';
      final matchesMaterial = filter.isEmpty ||
          filter.toLowerCase() == 'all' ||
          v.acceptedMaterials.any(
            (m) => m.toLowerCase() == filter.toLowerCase(),
          );

      return matchesSearch && matchesMaterial;
    }).map((v) {
      final fav = loyalty.isFavorite(v.id) || v.isFavorite;
      return v.copyWith(isFavorite: fav);
    }).toList();

    // Favorite first, then nearest.
    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return filtered;
  }

  Vendor? getVendorById(String id) {
    try {
      return _vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  void connectVendor(String vendorId) {
    for (int i = 0; i < _vendors.length; i++) {
      _vendors[i] = _vendors[i].copyWith(isConnected: _vendors[i].id == vendorId);
    }
    notifyListeners();
    LoyaltyRepository().recordChoose(vendorId);
  }

  Future<void> syncWithBackend({String? category}) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await ApiService.instance.restoreSession();
      await LoyaltyRepository().sync();
      final remoteVendors = await ApiService.instance.fetchNearbyVendors(
        category: category,
      );
      if (remoteVendors.isNotEmpty) {
        String? connectedId;
        for (final v in _vendors) {
          if (v.isConnected) {
            connectedId = v.id;
            break;
          }
        }
        final favoriteId = LoyaltyRepository().preferredFavoriteId;
        final loyalty = LoyaltyRepository();
        _vendors
          ..clear()
          ..addAll(
            remoteVendors.map((v) {
              final fav = loyalty.isFavorite(v.id) || v.isFavorite;
              final shouldConnect = favoriteId != null
                  ? v.id == favoriteId
                  : connectedId != null && v.id == connectedId;
              return v.copyWith(
                isFavorite: fav,
                isConnected: shouldConnect,
              );
            }),
          );
        _vendors.sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('VendorRepository.syncWithBackend failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
