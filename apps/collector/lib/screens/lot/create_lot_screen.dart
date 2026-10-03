import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/price.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/price_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/lot_valuation.dart';
import '../../widgets/custom_button.dart';
import 'create_lot_args.dart';

class CreateLotScreen extends StatefulWidget {
  final LotRepository? lotRepository;
  final PriceRepository? priceRepository;
  final ConnectivityService? connectivityService;

  const CreateLotScreen({
    super.key,
    this.lotRepository,
    this.priceRepository,
    this.connectivityService,
  });

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LotRepository _lotRepository;
  late final PriceRepository _priceRepository;
  late final ConnectivityService _connectivity;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lotRepository = widget.lotRepository ?? LotRepository();
    _connectivity = widget.connectivityService ?? ConnectivityService.instance;
    _priceRepository = widget.priceRepository ??
        PriceRepository(connectivityService: _connectivity);
    _loadRates();
  }

  String? _imagePath;
  String _selectedCategoryId = 'mixed_ewaste';
  double _weightKg = 5.0;
  String _selectedCondition = 'average';
  bool _isSaving = false;
  bool _appliedArgs = false;
  bool _usingFallbackRates = true;
  List<Price> _prices = PriceRepository.defaultPrices();

  final List<Map<String, String>> _categoryDefinitions = const [
    {'id': 'pcb_motherboard', 'key': 'categoryPcb', 'defaultName': 'Motherboard / PCB'},
    {'id': 'copper_wire', 'key': 'categoryCopper', 'defaultName': 'Copper Wire'},
    {'id': 'battery', 'key': 'categoryBattery', 'defaultName': 'Batteries'},
    {'id': 'display_monitor', 'key': 'categoryDisplay', 'defaultName': 'Monitors & Displays'},
    {'id': 'heavy_appliances', 'key': 'categoryAppliances', 'defaultName': 'Heavy Electricals'},
    {'id': 'plastic', 'key': 'categoryPlastic', 'defaultName': 'Plastic'},
    {'id': 'paper', 'key': 'categoryPaper', 'defaultName': 'Paper'},
    {'id': 'book', 'key': 'categoryBook', 'defaultName': 'Books'},
    {'id': 'mixed_ewaste', 'key': 'categoryMixed', 'defaultName': 'Mixed E-Waste'},
  ];

  Future<void> _loadRates() async {
    try {
      final data = await _priceRepository.fetchPrices();
      if (!mounted) return;
      setState(() {
        _prices = data.prices;
        _usingFallbackRates = data.isOffline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prices = PriceRepository.defaultPrices();
        _usingFallbackRates = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedArgs) return;
    _appliedArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CreateLotArgs) {
      _applyDraft(args);
    } else if (args is String && args.isNotEmpty) {
      _imagePath = args;
    }
  }

  void _applyDraft(CreateLotArgs draft) {
    _imagePath = draft.imagePath;
    if (draft.categoryId != null && draft.categoryId!.isNotEmpty) {
      _selectedCategoryId = draft.categoryId!;
    }
    if (draft.weightKg != null && draft.weightKg! > 0) {
      _weightKg = draft.weightKg!.clamp(0.5, 1000.0);
    }
    if (draft.condition != null && draft.condition!.isNotEmpty) {
      _selectedCondition = draft.condition!;
    }
    if (draft.notes != null && draft.notes!.trim().isNotEmpty) {
      _notesController.text = draft.notes!.trim();
    } else {
      final bits = [
        if (draft.electronicDevice != null && draft.electronicDevice!.trim().isNotEmpty)
          draft.electronicDevice!.trim(),
        if (draft.shortDescription != null && draft.shortDescription!.trim().isNotEmpty)
          draft.shortDescription!.trim(),
      ];
      if (bits.isNotEmpty) {
        _notesController.text = bits.join('. ');
      }
    }
  }

  String _getCategoryName(String id, AppLocalizations loc) {
    final match = _categoryDefinitions.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {'id': id, 'key': '', 'defaultName': id},
    );
    final key = match['key'];
    if (key != null && key.isNotEmpty) {
      return loc.translate(key);
    }
    return match['defaultName'] ?? id;
  }

  (double, double) _estimateRange() {
    return LotValuation.estimateRange(
      categoryId: _selectedCategoryId,
      weightKg: _weightKg,
      condition: _selectedCondition,
      prices: _prices,
    );
  }

  Future<void> _handleSave(AppLocalizations loc) async {
    if (!_formKey.currentState!.validate()) return;
    if (_weightKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('validWeightError'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final range = _estimateRange();
    final categoryName = _getCategoryName(_selectedCategoryId, loc);

    final savedLot = await _lotRepository.saveLotLocally(
      categoryId: _selectedCategoryId,
      categoryName: categoryName,
      weightKg: _weightKg,
      condition: _selectedCondition,
      imagePath: _imagePath,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      minPrice: range.$1,
      maxPrice: range.$2,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.translate('lotSavedSuccess')),
        backgroundColor: AppColors.syncSuccess,
        duration: const Duration(seconds: 3),
      ),
    );
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed('/lot-details', arguments: savedLot);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final range = _estimateRange();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('createLot')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imagePath != null && !kIsWeb && File(_imagePath!).existsSync())
                Container(
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              Text(
                loc.translate('selectCategory'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedCategoryId),
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _categoryDefinitions.map((cat) {
                  final key = cat['key']!;
                  return DropdownMenuItem(
                    value: cat['id'],
                    child: Text(loc.translate(key), style: const TextStyle(fontSize: 16)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategoryId = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              Text(
                loc.translate('enterWeight'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        Formatters.weight(_weightKg),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStepBtn('-1 kg', () => setState(() => _weightKg = (_weightKg - 1).clamp(0.5, 1000.0))),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStepBtn('+1 kg', () => setState(() => _weightKg += 1)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStepBtn('+5 kg', () => setState(() => _weightKg += 5)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildStepBtn('+10 kg', () => setState(() => _weightKg += 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                loc.translate('selectCondition'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildConditionChip('good', loc.translate('conditionGood'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildConditionChip('average', loc.translate('conditionAverage'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildConditionChip('scrap', loc.translate('conditionScrap'))),
                ],
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('estimatedValue'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.priceRange(range.$1, range.$2),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.translate('valueFactors'),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (_usingFallbackRates) ...[
                        const SizedBox(height: 6),
                        Text(
                          loc.translate('usingCachedRates'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (LotValuation.isPotentialCriticalCategory(_selectedCategoryId)) ...[
                        const SizedBox(height: 8),
                        Text(
                          loc.translate('potentialCriticalMineral'),
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                loc.translate('optionalNotes'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: loc.translate('notesHint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),

              CustomButton(
                label: loc.translate('saveLot'),
                icon: Icons.save_alt_rounded,
                isLoading: _isSaving,
                onPressed: () => _handleSave(loc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBtn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildConditionChip(String value, String label) {
    final isSelected = _selectedCondition == value;
    return ChoiceChip(
      label: Container(
        alignment: Alignment.center,
        height: 36,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      onSelected: (_) => setState(() => _selectedCondition = value),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
