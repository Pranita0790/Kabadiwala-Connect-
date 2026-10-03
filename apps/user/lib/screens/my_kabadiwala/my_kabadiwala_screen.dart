import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';

class MyKabadiwalaScreen extends StatefulWidget {
  const MyKabadiwalaScreen({Key? key}) : super(key: key);

  @override
  State<MyKabadiwalaScreen> createState() => _MyKabadiwalaScreenState();
}

class _MyKabadiwalaScreenState extends State<MyKabadiwalaScreen> {
  late Vendor _preferredVendor;

  @override
  void initState() {
    super.initState();
    // Default preferred kabadiwala is Ramesh Kumar
    _preferredVendor = VendorRepository().getNearbyVendors().first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Kabadiwala'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/nearby-vendors');
            },
            icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
            label: const Text(
              'Change',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preferred Kabadiwala Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _preferredVendor.name[0],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _preferredVendor.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: AppColors.primary, size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _preferredVendor.shopName,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        _preferredVendor.rating.toString(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${_preferredVendor.distanceKm} km away',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _preferredVendor.address,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Operating Hours: ${_preferredVendor.operatingHours}',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        '/select-material',
                        arguments: _preferredVendor,
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Request Pickup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/reminders');
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Reminders'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Current Rates Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Buying Rates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Updated Today',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _preferredVendor.rates.length,
              itemBuilder: (context, index) {
                final category = _preferredVendor.rates.keys.elementAt(index);
                final rate = _preferredVendor.rates[category]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getCategoryIcon(category), size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${rate.toStringAsFixed(0)} / kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Past Collection History Button
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.primary),
                ),
                title: const Text(
                  'Collection History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text('View all completed collections by this Kabadiwala'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.of(context).pushNamed('/collection-history');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'paper':
      case 'newspaper':
      case 'cardboard':
        return Icons.description_outlined;
      case 'plastic':
      case 'bottles':
        return Icons.local_drink_outlined;
      case 'metal':
      case 'iron':
      case 'aluminum':
        return Icons.hardware_outlined;
      case 'e-waste':
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.recycling_outlined;
    }
  }
}
