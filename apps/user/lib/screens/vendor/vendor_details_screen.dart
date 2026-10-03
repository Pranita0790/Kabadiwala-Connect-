import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';
import '../sell/sell_materials_screen.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String? vendorId;
  final Vendor? vendor;

  const VendorDetailsScreen({super.key, this.vendorId, this.vendor});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  final VendorRepository _repository = VendorRepository();

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor ?? _repository.getVendorById(widget.vendorId ?? '') ?? _repository.connectedVendor;

    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor Profile')),
        body: const Center(child: Text('Vendor not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kabadiwala Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        v.name[0],
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      v.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${v.distanceKm.toStringAsFixed(1)} km away · Collector',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${v.rating} Rating (120+ verified pickups)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _repository.connectVendor(v.id);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${v.name} set as your primary Kabadiwala')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: v.isConnected ? AppColors.secondary : AppColors.primary,
                            ),
                            child: Text(v.isConnected ? 'Connected ✓' : 'Connect Kabadiwala'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vendor Buying Rates Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Material Buying Rates',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Divider(height: 20),
                    ...v.displayRates.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(fontSize: 15, color: AppColors.textMain),
                              ),
                            ),
                            Text(
                              '₹${e.value.toStringAsFixed(0)} / kg',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact & Address Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact & Location',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(v.phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(v.address, style: const TextStyle(fontSize: 14, color: AppColors.textMain)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _repository.connectVendor(v.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellMaterialsScreen(vendor: v),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Request Scrap Pickup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
