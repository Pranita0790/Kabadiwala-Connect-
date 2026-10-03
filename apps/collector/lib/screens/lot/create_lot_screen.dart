import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/price.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/price_repository.dart';
import '../../services/ai_classification_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/lot_valuation.dart';
import '../../services/remote_ai_classification_service.dart';
import '../../services/backend_url.dart';
import '../../widgets/custom_button.dart';

class CreateLotScreen extends StatefulWidget {
  final LotRepository? lotRepository;
  final AiClassificationService? aiService;
  final PriceRepository? priceRepository;
  final ConnectivityService? connectivityService;

  const CreateLotScreen({
    super.key,
    this.lotRepository,
    this.aiService,
    this.priceRepository,
    this.connectivityService,
  });

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LotRepository _lotRepository;
  late final AiClassificationService _aiService;
  late final PriceRepository _priceRepository;
  late final ConnectivityService _connectivity;
  final TextEditingController _notesController = TextEditingController();

  static const bool _useMockAi = bool.fromEnvironment('USE_MOCK_AI', defaultValue: false);

  @override
  void initState() {
    super.initState();
    _lotRepository = widget.lotRepository ?? LotRepository();
    _connectivity = widget.connectivityService ?? ConnectivityService.instance;
    _priceRepository = widget.priceRepository ??
        PriceRepository(connectivityService: _connectivity);
    _aiService = widget.aiService ??
        (_useMockAi
            ? MockAiClassificationService()
            : RemoteAiClassificationService(baseUrl: AppConstants.backendBaseUrl));
    _loadRates();
  }

  String? _imagePath;
  String _selectedCategoryId = 'mixed_ewaste';
  double _weightKg = 5.0;
  String _selectedCondition = 'average';

  bool _isAnalyzingAi = false;
  bool _isSaving = false;
  bool _isAiSuggested = false;
  bool _aiAnalysisFailed = false;
  bool _aiLowConfidence = false;
  bool _aiNeedsConnection = false;
  bool _isMockAiResult = false;
  String? _aiElectronicDevice;
  String? _aiShortDescription;
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
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String? && args != null && _imagePath == null) {
      _imagePath = args;
      _triggerAiClassification(_imagePath!);
    }
  }

  Future<void> _triggerAiClassification(String path) async {
    setState(() {
      _isAnalyzingAi = true;
      _aiAnalysisFailed = false;
      _aiLowConfidence = false;
      _aiNeedsConnection = false;
      _isAiSuggested = false;
      _isMockAiResult = false;
      _aiElectronicDevice = null;
      _aiShortDescription = null;
    });

    // Always try the backend (USB reverse works even if Wi‑Fi/data looks offline).
    final result = await _aiService.classifyEWasteImage(path);
    if (!mounted) return;

    final loc = AppLocalizations.of(context);
    setState(() {
      _isAnalyzingAi = false;
      if (result == null) {
        _aiAnalysisFailed = true;
        final err = BackendUrl.lastError ?? '';
        _aiNeedsConnection = err.contains('SocketException') ||
            err.contains('Failed host lookup') ||
            err.contains('timed out') ||
            err.contains('Connection refused');
        return;
      }

      _isMockAiResult = result.isMockResult;
      _aiElectronicDevice = result.electronicDevice;
      _aiShortDescription = result.shortDescription;
      if (LotValuation.shouldAutoSelect(result)) {
        _selectedCategoryId = result.categoryId;
        if (result.weightKg != null && result.weightKg! > 0) {
          _weightKg = result.weightKg!.clamp(0.5, 1000.0);
        }
        if (result.condition != null) {
          _selectedCondition = result.condition!;
        }
        final categoryName = _getCategoryName(result.categoryId, loc);
        final device = (result.electronicDevice ?? result.categoryName).trim();
        final desc = (result.shortDescription ?? result.notes ?? '').trim();
        final percent = (result.confidenceScore * 100).clamp(0, 100).round();
        _notesController.text = [
          if (device.isNotEmpty) device,
          if (desc.isNotEmpty) desc,
          '$categoryName ($percent%)',
        ].join('. ');
        _isAiSuggested = true;
        _aiAnalysisFailed = false;
        _aiLowConfidence = false;
      } else {
        _aiLowConfidence = true;
        _aiAnalysisFailed = true;
        _isAiSuggested = false;
      }
    });
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

              if (_isAnalyzingAi)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(loc.translate('analyzingAi'))),
                    ],
                  ),
                )
              else if (_isAiSuggested)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isMockAiResult
                                  ? loc.translate('mockAiLabel')
                                  : loc.translate('suggestedAi'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_aiElectronicDevice != null &&
                          _aiElectronicDevice!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${loc.translate('aiIdentifiedItem')}: ${_aiElectronicDevice!}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      Text(
                        '${loc.translate('aiMatchedCategory')}: ${_getCategoryName(_selectedCategoryId, loc)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_aiShortDescription != null &&
                          _aiShortDescription!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _aiShortDescription!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                )
              else if ((_aiAnalysisFailed || _aiLowConfidence) && _imagePath != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _aiNeedsConnection
                              ? loc.translate('aiNeedsConnection')
                              : _aiLowConfidence
                                  ? loc.translate('aiLowConfidence')
                                  : loc.translate('aiAnalysisFailed'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      if (!_aiNeedsConnection)
                        TextButton(
                          onPressed: () => _triggerAiClassification(_imagePath!),
                          child: Text(loc.translate('retryAi')),
                        ),
                    ],
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
                      _isAiSuggested = false;
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
