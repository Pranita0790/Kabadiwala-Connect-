import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/material_item.dart';
import '../../models/vendor.dart';
import '../../repositories/loyalty_repository.dart';
import '../../repositories/vendor_repository.dart';

class MyKabadiwalaScreen extends StatefulWidget {
  const MyKabadiwalaScreen({Key? key}) : super(key: key);

  @override
  State<MyKabadiwalaScreen> createState() => _MyKabadiwalaScreenState();
}

class _MyKabadiwalaScreenState extends State<MyKabadiwalaScreen> {
  final VendorRepository _repository = VendorRepository();
  String? _rateFilter;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChange);
    LoyaltyRepository().addListener(_onRepoChange);
    _repository.syncWithBackend();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepoChange);
    LoyaltyRepository().removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  Vendor? get _preferredVendor => _repository.connectedVendor;

  @override
  Widget build(BuildContext context) {
    final vendor = _preferredVendor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Kabadiwala'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/nearby-vendors').then((_) {
                if (mounted) setState(() {});
              });
            },
            icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
            label: const Text(
              'Change',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: vendor == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No kabadiwala connected yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect a nearby collector to see rates and request pickup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/nearby-vendors'),
                      child: const Text('Find Nearby Collectors'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  vendor.name.isNotEmpty ? vendor.name[0] : 'K',
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
                                      Flexible(
                                        child: Text(
                                          vendor.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified, color: AppColors.primary, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (vendor.isFavorite ||
                                            LoyaltyRepository().isFavorite(vendor.id))
                                        ? 'Favorite Kabadiwala'
                                        : (vendor.isCollector
                                            ? 'Connected collector'
                                            : vendor.shopName),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              vendor.rating.toString(),
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
                                        '${vendor.distanceKm.toStringAsFixed(1)} km away',
                                        style: const TextStyle(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                vendor.address,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
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
                              'Operating Hours: ${vendor.operatingHours}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/select-material',
                              arguments: vendor,
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Current Buying Rates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '5 categories',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _rateFilter == null,
                            label: const Text('All'),
                            onSelected: (_) => setState(() => _rateFilter = null),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _rateFilter == null ? Colors.white : AppColors.textPrimary,
                            ),
                            checkmarkColor: Colors.white,
                          ),
                        ),
                        ...MaterialItem.defaultMaterials.map((m) {
                          final selected = _rateFilter == m.category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: selected,
                              label: Text(m.category),
                              onSelected: (_) => setState(() => _rateFilter = m.category),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppColors.textPrimary,
                              ),
                              checkmarkColor: Colors.white,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._rateEntries(vendor).map((entry) {
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
                              Icon(_getCategoryIcon(entry.key), size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${entry.value.toStringAsFixed(0)} / kg',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

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
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
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

  List<MapEntry<String, double>> _rateEntries(Vendor vendor) {
    final entries = vendor.displayRates;
    if (_rateFilter == null) return entries;
    final filter = _rateFilter!.toLowerCase();
    if (vendor.rateCard.isNotEmpty) {
      return vendor.rateCard
          .where((r) =>
              r.materialCategory.toLowerCase() == filter ||
              r.materialName.toLowerCase().contains(filter))
          .map((r) => MapEntry(r.materialName, r.ratePerKg))
          .toList();
    }
    return entries
        .where((e) => e.key.toLowerCase() == filter)
        .toList();
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
        return Icons.widgets_outlined;
    }
  }
}
