import 'package:flutter/material.dart';
import '../../models/material_item.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';
import 'sell_materials_screen.dart';
import 'select_material_screen.dart';

/// Legacy entry — redirects into the new sell flow
/// (Kabadiwala → materials → cost → pickup/shop → pay → review).
class CreateRequestScreen extends StatelessWidget {
  final MaterialItem? selectedMaterial;
  final List<String>? selectedMaterialNames;
  final Vendor? assignedVendor;

  const CreateRequestScreen({
    super.key,
    this.selectedMaterial,
    this.selectedMaterialNames,
    this.assignedVendor,
  });

  @override
  Widget build(BuildContext context) {
    final vendor = assignedVendor ??
        VendorRepository().connectedVendor ??
        (VendorRepository().allVendors.isNotEmpty
            ? VendorRepository().allVendors.first
            : null);

    if (vendor == null) {
      return const SelectMaterialScreen();
    }

    return SellMaterialsScreen(vendor: vendor);
  }
}
