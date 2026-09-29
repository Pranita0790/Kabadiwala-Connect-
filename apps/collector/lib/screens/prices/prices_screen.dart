import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/price.dart';
import '../../repositories/price_repository.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/price_card.dart';

class PricesScreen extends StatefulWidget {
  final Locale currentLocale;
  final PriceRepository? priceRepository;
  final ConnectivityService? connectivityService;

  const PricesScreen({
    super.key,
    required this.currentLocale,
    this.priceRepository,
    this.connectivityService,
  });

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  late final PriceRepository _priceRepository;
  late final ConnectivityService _connectivityService;

  List<Price> _prices = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String _selectedLocation = 'All';
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _priceRepository = widget.priceRepository ?? PriceRepository();
    _connectivityService = widget.connectivityService ?? ConnectivityService.instance;
    _initConnectivityListener();
    _loadPrices();
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        _loadPrices();
      }
    });
  }

  Future<void> _loadPrices({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final data = await _priceRepository.fetchPrices(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _prices = data.prices;
        _isOffline = data.isOffline;
        _isLoading = false;
      });
    }
  }

  List<Price> get _filteredPrices {
    if (_selectedLocation == 'All') return _prices;
    return _prices.where((p) => p.location.toLowerCase() == _selectedLocation.toLowerCase()).toList();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final langCode = widget.currentLocale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('priceBoard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: loc.translate('refreshPrices'),
            onPressed: () => _loadPrices(forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPrices(forceRefresh: true),
        child: Column(
          children: [
            // Status Banner: Online Live vs Offline SQLite Cache
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _isOffline
                  ? AppColors.syncPending.withValues(alpha: 0.15)
                  : AppColors.syncSuccess.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.cloud_done_rounded,
                    size: 20,
                    color: _isOffline ? AppColors.syncPending : AppColors.syncSuccess,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isOffline
                          ? loc.translate('cachedOfflineRates')
                          : loc.translate('liveRates'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isOffline ? AppColors.syncPending : AppColors.syncSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', loc.translate('all')),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nagpur', 'Nagpur (नागपूर)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Mumbai', 'Mumbai (मुंबई)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pune', 'Pune (पुणे)'),
                  ],
                ),
              ),
            ),

            // Price List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPrices.isEmpty
                      ? Center(
                          child: Text(
                            loc.translate('noLots'),
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          itemCount: _filteredPrices.length,
                          itemBuilder: (context, index) {
                            final item = _filteredPrices[index];
                            return PriceCard(
                              price: item,
                              currentLanguage: langCode,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String locationKey, String label) {
    final isSelected = _selectedLocation == locationKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedLocation = locationKey);
        }
      },
    );
  }
}
