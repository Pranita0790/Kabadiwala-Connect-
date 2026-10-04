import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/utils/formatters.dart';
import '../../data/mpcb_recyclers_directory.dart';
import '../../models/e_waste_lot.dart';
import '../../models/recycler.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/recycler_repository.dart';
import '../handover/handover_qr_screen.dart';

class RecyclerMatchingScreen extends StatefulWidget {
  final EWasteLot? lot;
  final String? selectedCategory;
  final List<Recycler>? initialRecyclers;
  final RecyclerRepository? recyclerRepository;
  final LotRepository? lotRepository;

  const RecyclerMatchingScreen({
    super.key,
    this.lot,
    this.selectedCategory,
    this.initialRecyclers,
    this.recyclerRepository,
    this.lotRepository,
  });

  @override
  State<RecyclerMatchingScreen> createState() => _RecyclerMatchingScreenState();
}

class _RecyclerMatchingScreenState extends State<RecyclerMatchingScreen> {
  late final RecyclerRepository _recyclerRepo;
  late final LotRepository _lotRepo;

  List<Recycler> _recyclers = [];
  bool _isLoading = true;
  bool _isMapView = false;
  bool _sortByPrice = false;
  String? _errorMessage;
  Recycler? _selectedRecycler;
  EWasteLot? _boundLot;

  // Live Location State (Default: Pune Bhosari / Pimpri)
  double _collectorLat = 18.6272;
  double _collectorLng = 73.8344;
  String _currentLocationName = 'Pune (Bhosari / Pimpri-Chinchwad)';

  // Active Category Filter
  String _activeCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'en': '🌟 All MPCB Units', 'hi': '🌟 सभी रिसाइकिलर', 'mr': '🌟 सर्व MPCB युनिट्स'},
    {'id': 'e_waste', 'en': '⚡ E-Waste Recyclers', 'hi': '⚡ ई-कचरा', 'mr': '⚡ ई-कचरा रिसायकलर्स'},
    {'id': 'battery', 'en': '🔋 Battery & Li-ion', 'hi': '🔋 बैटरी स्क्रैप', 'mr': '🔋 बॅटरी व लिथियम'},
    {'id': 'non_ferrous', 'en': '🥉 Copper, Brass & Zinc', 'hi': '🥉 तांबा, पीतल व जिंक', 'mr': '🥉 तांबे, पितळ व अ‍ॅल्युमिनियम'},
    {'id': 'plastic', 'en': '♻️ Plastic Processors', 'hi': '♻️ प्लास्टिक', 'mr': '♻️ प्लॅस्टिक प्रक्रिया'},
    {'id': 'ferrous', 'en': '🏗️ Ferrous & Steel', 'hi': '🏗️ लोहा व स्टील', 'mr': '🏗️ लोखंड व स्टील'},
    {'id': 'vehicle_scrapping', 'en': '🚗 Vehicle Scrapping (RVSF)', 'hi': '🚗 वाहन स्क्रैप', 'mr': '🚗 वाहन स्क्रॅपिंग (RVSF)'},
    {'id': 'tyre', 'en': '🛞 Tyre & Pyrolysis', 'hi': '🛞 टायर स्क्रैप', 'mr': '🛞 टायर व रबर'},
    {'id': 'used_oil', 'en': '🛢️ Used & Waste Oil', 'hi': '🛢️ प्रयुक्त तेल', 'mr': '🛢️ वापरलेले तेल'},
    {'id': 'spent_solvent', 'en': '🧪 Spent Solvents', 'hi': '🧪 सॉल्वेंट रिफाइनरी', 'mr': '🧪 सॉल्व्हेंट डिस्टिलेशन'},
  ];

  @override
  void initState() {
    super.initState();
    _recyclerRepo = widget.recyclerRepository ?? RecyclerRepository();
    _lotRepo = widget.lotRepository ?? LotRepository();
    _boundLot = widget.lot;

    if (widget.selectedCategory != null && widget.selectedCategory!.isNotEmpty) {
      _activeCategory = widget.selectedCategory!;
    }

    _refreshMatchedRecyclers();

    if (_boundLot == null && widget.lotRepository != null) {
      _bindLatestSavedLot();
    }
  }

  Future<void> _bindLatestSavedLot() async {
    try {
      final lots = await _lotRepo.getLots();
      if (!mounted || lots.isEmpty || _boundLot != null) return;
      setState(() {
        _boundLot = lots.first;
      });
    } catch (_) {}
  }

  Future<void> _refreshMatchedRecyclers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Live signed-up recyclers from Node `/api/recyclers` first…
    List<Recycler> apiRecyclers = const [];
    try {
      final result = await _recyclerRepo.fetchMatchingRecyclers(
        categoryId: _activeCategory == 'all' ? null : _activeCategory,
        forceRefresh: true,
      );
      apiRecyclers = result.recyclers;
    } catch (_) {
      // Fall through to MPCB directory offline.
    }

    // …then MPCB directory as secondary offline catalogue.
    final mpcb = MpcbRecyclersDirectory.getMatchedRecyclers(
      collectorLat: _collectorLat,
      collectorLng: _collectorLng,
      categoryId: _activeCategory,
      searchFilter: _searchQuery,
      sortByPrice: _sortByPrice,
    );

    final seen = <String>{};
    final merged = <Recycler>[];
    for (final r in [...apiRecyclers, ...mpcb]) {
      final key = r.id.isNotEmpty ? r.id : r.name.toLowerCase();
      if (seen.add(key)) merged.add(r);
    }

    final q = _searchQuery.trim().toLowerCase();
    var list = q.isEmpty
        ? merged
        : merged
            .where(
              (r) =>
                  r.name.toLowerCase().contains(q) ||
                  r.address.toLowerCase().contains(q),
            )
            .toList();

    if (_sortByPrice) {
      list = List<Recycler>.from(list)
        ..sort(
          (a, b) => (b.indicativePrice ?? 0).compareTo(a.indicativePrice ?? 0),
        );
    } else {
      // API / authorized orgs stay on top, then nearest.
      list = List<Recycler>.from(list)
        ..sort((a, b) {
          if (a.isDemo != b.isDemo) return a.isDemo ? 1 : -1;
          if (a.isAuthorized != b.isAuthorized) {
            return a.isAuthorized ? -1 : 1;
          }
          return a.distanceKm.compareTo(b.distanceKm);
        });
    }

    if (!mounted) return;
    setState(() {
      _recyclers = list;
      _isLoading = false;
      if (_recyclers.isNotEmpty) {
        _selectedRecycler = _recyclers.first;
      } else {
        _selectedRecycler = null;
        _errorMessage = 'No recyclers found for this filter.';
      }
    });
  }

  void _onSelectRecycler(Recycler recycler) {
    setState(() {
      _selectedRecycler = recycler;
    });
  }

  void _changeLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.my_location, color: Color(0xFF134233)),
                      SizedBox(width: 8),
                      Text(
                        'Select Collector Location',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF134233)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Distances & highest-paying buyers calculate dynamically in real-time from your active location.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: MpcbRecyclersDirectory.presetCollectorLocations.length,
                  itemBuilder: (context, index) {
                    final loc = MpcbRecyclersDirectory.presetCollectorLocations[index];
                    final isSelected = loc['name'] == _currentLocationName;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF134233) : Colors.grey,
                      ),
                      title: Text(
                        loc['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF134233) : Colors.black87,
                        ),
                      ),
                      subtitle: Text('Lat: ${loc['lat']}, Lng: ${loc['lng']}', style: const TextStyle(fontSize: 11)),
                      trailing: isSelected ? const Chip(label: Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Color(0xFF134233)) : null,
                      onTap: () {
                        setState(() {
                          _collectorLat = loc['lat'] as double;
                          _collectorLng = loc['lng'] as double;
                          _currentLocationName = loc['name'] as String;
                        });
                        Navigator.pop(ctx);
                        _refreshMatchedRecyclers();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToHandover(Recycler recycler) {
    final lot = _boundLot ?? widget.lot;
    if (lot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleController.instance.currentLanguageCode == 'mr'
                ? 'कृपया आधी स्क्रॅप लॉट निवडा किंवा तयार करा'
                : 'Please select or create a scrap lot first to handover',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HandoverQrScreen(
          recycler: recycler,
          lot: lot,
        ),
      ),
    );
  }

  void _showRecyclerDetails(Recycler recycler) {
    final lang = LocaleController.instance.currentLanguageCode;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.factory_rounded, color: Color(0xFF134233), size: 30),
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
                                recycler.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF134233),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF81C784)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 14, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 4),
                                  Text(
                                    'MPCB 2025',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recycler.address,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(
                    icon: Icons.near_me_rounded,
                    label: '${recycler.distanceKm.toStringAsFixed(1)} km',
                    subtitle: lang == 'mr' ? 'अंतर (Live)' : 'Distance (Live)',
                  ),
                  _InfoChip(
                    icon: Icons.payments_rounded,
                    label: '₹${recycler.indicativeRatePerKg.toStringAsFixed(0)}/${recycler.unit}',
                    subtitle: lang == 'mr' ? 'दर' : 'Benchmark Rate',
                    color: const Color(0xFF2E7D32),
                  ),
                  _InfoChip(
                    icon: Icons.precision_manufacturing_rounded,
                    label: recycler.capacity ?? 'Authorized',
                    subtitle: 'Capacity',
                    color: Colors.blueGrey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (recycler.contactPerson != null || recycler.contactPhone != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF134233), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recycler.contactPerson ?? 'Official Representative',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (recycler.contactPhone != null)
                              Text('📞 ${recycler.contactPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _navigateToHandover(recycler);
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: Text(
                    lang == 'mr' ? 'हस्तांतरण प्रक्रिया सुरू करा (Handover)' : 'Proceed to Handover (QR)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF134233),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.instance.currentLanguageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang == 'mr'
              ? 'MPCB अधिकृत रिसायकलर्स'
              : lang == 'hi'
                  ? 'MPCB अधिकृत रिसाइकिलर्स'
                  : 'MPCB Authorized Recyclers',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF134233),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list_alt_rounded : Icons.map_rounded),
            tooltip: _isMapView ? 'List View' : 'Map View',
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Live Collector Location Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE8F5E9),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF1B5E20), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'mr' ? 'कलेक्टरचे थेट स्थान (Live Location):' : 'Collector Live GPS Proximity:',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                      Text(
                        _currentLocationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF134233)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF134233),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
                  label: Text(
                    lang == 'mr' ? 'बदला' : 'Change',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _changeLocationSheet,
                ),
              ],
            ),
          ),

          // 2. Search & Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: lang == 'mr' ? 'नाव, MIDC किंवा जिल्हा शोधा...' : 'Search facility, MIDC, district...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFC8E6C9))),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF9),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _refreshMatchedRecyclers();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sortByPrice ? Icons.currency_rupee : Icons.near_me, size: 14, color: _sortByPrice ? Colors.white : const Color(0xFF134233)),
                      const SizedBox(width: 4),
                      Text(
                        _sortByPrice ? (lang == 'mr' ? 'जास्त भाव' : 'Top Rate') : (lang == 'mr' ? 'जवळचे' : 'Nearest'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _sortByPrice ? Colors.white : const Color(0xFF134233)),
                      ),
                    ],
                  ),
                  selected: _sortByPrice,
                  selectedColor: const Color(0xFF134233),
                  backgroundColor: const Color(0xFFE8F5E9),
                  onSelected: (val) {
                    setState(() => _sortByPrice = val);
                    _refreshMatchedRecyclers();
                  },
                ),
              ],
            ),
          ),

          // 3. Category Filter Horizontal List
          Container(
            height: 46,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _activeCategory == cat['id'];
                final label = cat[lang] ?? cat['en']!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF134233),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF134233),
                    backgroundColor: const Color(0xFFF1F8F5),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (selected) {
                      setState(() {
                        _activeCategory = cat['id']!;
                      });
                      _refreshMatchedRecyclers();
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 4. Main Content (List or Map)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF134233)))
                : _isMapView
                    ? _buildMapRadarView()
                    : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    final lang = LocaleController.instance.currentLanguageCode;

    if (_recyclers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              lang == 'mr' ? 'या श्रेणीत कोणतीही MPCB युनिट आढळली नाही' : 'No MPCB authorized units found for this filter',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recyclers.length,
      itemBuilder: (context, index) {
        final r = _recyclers[index];
        final isSelected = _selectedRecycler?.id == r.id;

        return Card(
          elevation: isSelected ? 3 : 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? const Color(0xFF134233) : const Color(0xFFE0E0E0),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onSelectRecycler(r),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF134233),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF134233),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: Text(
                              '₹${r.indicativeRatePerKg.toStringAsFixed(0)}/${r.unit}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '📍 ${r.distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Category & Capacity Badge Row
                  Row(
                    children: [
                      if (r.categoryLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: Text(
                            r.categoryLabel!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                          ),
                        ),
                      const SizedBox(width: 6),
                      if (r.capacity != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            'Cap: ${r.capacity!}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons Row
                  Row(
                    children: [
                      if (r.contactPhone != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF134233),
                              side: const BorderSide(color: Color(0xFF134233)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            icon: const Icon(Icons.call, size: 14),
                            label: Text(r.contactPhone!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _showRecyclerDetails(r),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF134233),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          icon: const Icon(Icons.qr_code_2, size: 14),
                          label: Text(
                            lang == 'mr' ? 'हस्तांतरण करा' : 'Deliver Scrap',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _navigateToHandover(r),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapRadarView() {
    final active = _selectedRecycler ?? (_recyclers.isNotEmpty ? _recyclers.first : null);
    final centerLat = active?.latitude ?? _collectorLat;
    final centerLng = active?.longitude ?? _collectorLng;

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // OpenStreetMap Tile Canvas
                Image.network(
                  'https://tile.openstreetmap.org/12/${_deg2num(centerLat, centerLng).item1}/${_deg2num(centerLat, centerLng).item2}.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF0F172A),
                    child: CustomPaint(painter: _RadarGridPainter()),
                  ),
                ),
                Container(color: Colors.black.withValues(alpha: 0.25)),

                // Facility Marker Pins
                ..._recyclers.map((r) {
                  final isSel = r.id == active?.id;
                  final dx = 180.0 + (r.longitude - centerLng) * 1200.0;
                  final dy = 240.0 - (r.latitude - centerLat) * 1200.0;

                  return Positioned(
                    left: dx.clamp(20.0, 340.0),
                    top: dy.clamp(40.0, 480.0),
                    child: GestureDetector(
                      onTap: () => _onSelectRecycler(r),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF69F0AE) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                            ),
                            child: Text(
                              '₹${r.indicativeRatePerKg.toStringAsFixed(0)}/kg',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF134233)),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            size: isSel ? 36 : 26,
                            color: isSel ? Colors.redAccent : const Color(0xFF134233),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Bottom Selected Inspection Card
        if (active != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            active.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF134233)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${active.indicativeRatePerKg.toStringAsFixed(0)}/${active.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${active.distanceKm.toStringAsFixed(1)} km away • ${active.address}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showRecyclerDetails(active),
                            child: const Text('Details', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF134233),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _navigateToHandover(active),
                            child: const Text('Deliver (QR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Helper for OSM Tile coordinates calculation
  ({int item1, int item2}) _deg2num(double lat, double lon) {
    const zoom = 12;
    final latRad = lat * pi / 180.0;
    final n = 1 << zoom;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final y = ((1.0 - asinh(tan(latRad)) / pi) / 2.0 * n).floor();
    return (item1: x, item2: y);
  }

  double asinh(double x) => log(x + sqrt(x * x + 1.0));
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? const Color(0xFF134233)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF134233),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}
