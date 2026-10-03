import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vendor.dart';
import '../../repositories/vendor_repository.dart';
import 'sell_materials_screen.dart';

/// Sell flow: pick a kabadiwala / scrapper collector (not material cards).
class SelectMaterialScreen extends StatefulWidget {
  final Vendor? selectedVendor;
  final String? initialCategory;

  const SelectMaterialScreen({
    super.key,
    this.selectedVendor,
    this.initialCategory,
  });

  @override
  State<SelectMaterialScreen> createState() => _SelectMaterialScreenState();
}

class _SelectMaterialScreenState extends State<SelectMaterialScreen> {
  final VendorRepository _repository = VendorRepository();
  final _searchController = TextEditingController();
  late String _selectedCategory;

  static const _all = 'All';

  List<String> get _filters => [_all, ...VendorRepository.materialFilters];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory?.trim() ?? '';
    _selectedCategory = initial.isEmpty ? _all : initial;
    _repository.addListener(_onRepoChange);
    _sync();
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

  Future<void> _sync() async {
    final category = _selectedCategory == _all ? null : _selectedCategory;
    await _repository.syncWithBackend(category: category);
  }

  void _openCreate(Vendor vendor) {
    _repository.connectVendor(vendor.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellMaterialsScreen(vendor: vendor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = _repository.getNearbyVendors(
      searchQuery: _searchController.text,
      materialFilter: _selectedCategory == _all ? null : _selectedCategory,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choose Kabadiwala'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _repository.isLoading ? null : _sync,
            icon: _repository.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search scrapper by name or address...',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter == _selectedCategory;
                return FilterChip(
                  selected: selected,
                  label: Text(filter),
                  onSelected: (_) {
                    setState(() => _selectedCategory = filter);
                    _sync();
                  },
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                vendors.isEmpty
                    ? 'No scrapper nearby for this filter'
                    : 'Nearest collectors first · ${vendors.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _sync,
              child: vendors.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No kabadiwala / scrapper found.\nPull to refresh.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: vendors.length,
                      itemBuilder: (context, index) {
                        final v = vendors[index];
                        return _ScrapperCard(
                          vendor: v,
                          isNearest: index == 0,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/vendor-details',
                            arguments: v,
                          ),
                          onRequestPickup: () => _openCreate(v),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrapperCard extends StatelessWidget {
  final Vendor vendor;
  final bool isNearest;
  final VoidCallback onTap;
  final VoidCallback onRequestPickup;

  const _ScrapperCard({
    required this.vendor,
    required this.isNearest,
    required this.onTap,
    required this.onRequestPickup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : 'K',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vendor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (vendor.isFavorite)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Favorite',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            const Icon(Icons.verified, color: AppColors.primary, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendor.isFavorite
                              ? 'Favorite Kabadiwala · suggested'
                              : (vendor.isCollector
                                  ? 'Scrapper · Collector'
                                  : 'Kabadiwala'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                vendor.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${vendor.rating} · ${vendor.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (isNearest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Nearest',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (vendor.isConnected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Connected',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: vendor.acceptedMaterials.take(5).map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      child: const Text('View Profile'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRequestPickup,
                      child: const Text('Request Pickup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
