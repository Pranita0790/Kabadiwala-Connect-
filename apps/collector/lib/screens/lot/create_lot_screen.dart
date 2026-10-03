import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../repositories/lot_repository.dart';
import '../../services/ai_classification_service.dart';
import '../../services/remote_ai_classification_service.dart';
import '../../widgets/custom_button.dart';

class CreateLotScreen extends StatefulWidget {
  final LotRepository? lotRepository;
  final AiClassificationService? aiService;

  const CreateLotScreen({
    super.key,
    this.lotRepository,
    this.aiService,
  });

  @override
  State<CreateLotScreen> createState() => _CreateLotScreenState();
}

class _CreateLotScreenState extends State<CreateLotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LotRepository _lotRepository;
  late final AiClassificationService _aiService;
  final TextEditingController _notesController = TextEditingController();

  // Configure AI service implementation
  // Flutter calls the Node.js backend; the backend forwards to FastAPI internally.
  static const bool _useMockAi = bool.fromEnvironment('USE_MOCK_AI', defaultValue: false);

  @override
  void initState() {
    super.initState();
    _lotRepository = widget.lotRepository ?? LotRepository();
    _aiService = widget.aiService ?? 
        (_useMockAi 
            ? MockAiClassificationService() 
            : RemoteAiClassificationService(baseUrl: AppConstants.backendBaseUrl));
  }


  String? _imagePath;
  String _selectedCategoryId = 'mixed_ewaste';
  double _weightKg = 5.0;
  String _selectedCondition = 'average';

  bool _isAnalyzingAi = false;
  bool _isSaving = false;
  bool _isAiSuggested = false;
  bool _aiAnalysisFailed = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String? && args != null && _imagePath == null) {
      _imagePath = args;
      _triggerAiClassification(_imagePath!);
    }
  }

  /// Triggers AI classification via the Node.js backend gateway.
  Future<void> _triggerAiClassification(String path) async {
    setState(() {
      _isAnalyzingAi = true;
      _aiAnalysisFailed = false;
      _isAiSuggested = false;
    });

    final result = await _aiService.classifyEWasteImage(path);
    if (!mounted) return;

    final loc = AppLocalizations.of(context);
    setState(() {
      _isAnalyzingAi = false;
      if (result != null) {
        _selectedCategoryId = result.categoryId;
        if (result.weightKg != null && result.weightKg! > 0) {
          _weightKg = result.weightKg!.clamp(0.5, 1000.0);
        }
        if (result.condition != null) {
          _selectedCondition = result.condition!;
        }
        final percent = (result.confidenceScore * 100).clamp(0, 100).round();
        final categoryName = _getCategoryName(result.categoryId, loc);
        _notesController.text =
            '${loc.translate('suggestedAi')}: $categoryName ($percent%) · ${Formatters.weight(_weightKg)}';
        _isAiSuggested = true;
        _aiAnalysisFailed = false;
      } else {
        _aiAnalysisFailed = true;
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

  (double, double) _priceRatesFor(String categoryId) {
    switch (categoryId) {
      case 'copper_wire':
        return (450.0, 620.0);
      case 'pcb_motherboard':
        return (240.0, 290.0);
      case 'battery':
        return (70.0, 110.0);
      case 'display_monitor':
        return (100.0, 200.0);
      case 'heavy_appliances':
        return (80.0, 160.0);
      case 'plastic':
        return (12.0, 25.0);
      case 'paper':
        return (8.0, 15.0);
      case 'book':
        return (6.0, 12.0);
      default:
        return (50.0, 100.0);
    }
  }

  /// Rule: Local-first save. Persists metadata to SQLite with UUID v4 and PENDING_SYNC status
  Future<void> _handleSave(AppLocalizations loc) async {
    if (!_formKey.currentState!.validate()) return;
    if (_weightKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('validWeightError'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final rates = _priceRatesFor(_selectedCategoryId);
    final minPriceRate = rates.$1;
    final maxPriceRate = rates.$2;
    final categoryName = _getCategoryName(_selectedCategoryId, loc);

    await _lotRepository.saveLotLocally(
      categoryId: _selectedCategoryId,
      categoryName: categoryName,
      weightKg: _weightKg,
      condition: _selectedCondition,
      imagePath: _imagePath,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      minPrice: _weightKg * minPriceRate,
      maxPrice: _weightKg * maxPriceRate,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('lotSavedSuccess')),
          backgroundColor: AppColors.syncSuccess,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
              // Image Thumbnail Preview
              if (_imagePath != null)
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

              // AI Suggestion Banner
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                        loc.translate('suggestedAi'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_aiAnalysisFailed && _imagePath != null)
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
                          loc.translate('aiAnalysisFailed'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _triggerAiClassification(_imagePath!),
                        child: Text(loc.translate('retryAi')),
                      ),
                    ],
                  ),
                ),

              // 1. Material Category Dropdown
              Text(
                loc.translate('selectCategory'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // Rebuild when AI (or the user) changes the category so the
                // dropdown reflects the suggestion, not only the first value.
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

              // 2. Weight Selector with Step Buttons
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStepBtn('-1 kg', () => setState(() => _weightKg = (_weightKg - 1).clamp(0.5, 1000.0))),
                          _buildStepBtn('+1 kg', () => setState(() => _weightKg += 1)),
                          _buildStepBtn('+5 kg', () => setState(() => _weightKg += 5)),
                          _buildStepBtn('+10 kg', () => setState(() => _weightKg += 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Condition Cards
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

              // 4. Optional Notes Field
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

              // 5. Save Button (Local-First Persistence)
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConditionChip(String value, String label) {
    final isSelected = _selectedCondition == value;
    return ChoiceChip(
      label: Container(
        alignment: Alignment.center,
        height: 36,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
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
