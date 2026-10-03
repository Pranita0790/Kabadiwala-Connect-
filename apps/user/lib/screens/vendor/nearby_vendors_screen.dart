import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';

class NearbyVendorsScreen extends StatefulWidget {
  const NearbyVendorsScreen({super.key});

  @override
  State<NearbyVendorsScreen> createState() => _NearbyVendorsScreenState();
}

class _NearbyVendorsScreenState extends State<NearbyVendorsScreen> {
  final VendorRepository _repository = VendorRepository();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepoChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vendors = _repository.getNearbyVendors(searchQuery: _searchController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby Kabadiwalas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by vendor name or area...',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: vendors.length,
              itemBuilder: (context, index) {
                final v = vendors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.pushNamed(context, '/vendor-details', arguments: v),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                v.name[0],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        v.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${v.rating} • ${v.distanceKm} km away',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
