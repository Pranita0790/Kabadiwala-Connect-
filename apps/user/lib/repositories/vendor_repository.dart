import 'package:flutter/foundation.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';

class VendorRepository extends ChangeNotifier {
  static final VendorRepository _instance = VendorRepository._internal();
  factory VendorRepository() => _instance;
  VendorRepository._internal();

  final List<Vendor> _vendors = List.from(Vendor.sampleVendors);

  List<Vendor> get allVendors => List.unmodifiable(_vendors);

  Vendor? get connectedVendor => _vendors.firstWhere((v) => v.isConnected, orElse: () => _vendors.first);

  List<Vendor> getNearbyVendors({String? searchQuery, String? materialFilter}) {
    return _vendors.where((v) {
      bool matchesSearch = searchQuery == null ||
          searchQuery.trim().isEmpty ||
          v.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          v.location.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesMaterial = materialFilter == null ||
          materialFilter.trim().isEmpty ||
          v.acceptedMaterials.any((m) => m.toLowerCase() == materialFilter.toLowerCase());

      return matchesSearch && matchesMaterial;
    }).toList();
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
      if (_vendors[i].id == vendorId) {
        _vendors[i] = _vendors[i].copyWith(isConnected: true);
      } else {
        _vendors[i] = _vendors[i].copyWith(isConnected: false);
      }
    }
    notifyListeners();
  }

  Future<void> syncWithBackend() async {
    final remoteVendors = await ApiService.fetchNearbyVendors();
    if (remoteVendors.isNotEmpty) {
      _vendors.clear();
      _vendors.addAll(remoteVendors);
      notifyListeners();
    }
  }
}
