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
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: AppConstants.apiHost);

  @override
  void initState() {
    super.initState();
    _lotRepository = widget.lotRepository ?? LotRepository();
    _aiService = widget.aiService ?? 
        (_useMockAi 
            ? MockAiClassificationService() 
            : RemoteAiClassificationService(baseUrl: _backendUrl));
  }


  String? _imagePath;
  String _selectedCategoryId = 'pcb_motherboard';
  double _weightKg = 5.0;
  String _selectedCondition = 'good';

  bool _isAnalyzingAi = false;
  bool _isSaving = false;
  bool _isAiSuggested = false;

  final List<Map<String, String>> _categoryDefinitions = const [
    {'id': 'pcb_motherboard', 'key': 'categoryPcb', 'defaultName': 'Motherboard / PCB'},
    {'id': 'copper_wire', 'key': 'categoryCopper', 'defaultName': 'Copper Wire'},
    {'id': 'battery', 'key': 'categoryBattery', 'defaultName': 'Batteries'},
    {'id': 'display_monitor', 'key': 'categoryDisplay', 'defaultName': 'Monitors & Displays'},
    {'id': 'heavy_appliances', 'key': 'categoryAppliances', 'defaultName': 'Heavy Electricals'},
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

  /// Triggers AI classification abstraction (Mock AI interface execution)
  Future<void> _triggerAiClassification(String path) async {
    setState(() => _isAnalyzingAi = true);
    final result = await _aiService.classifyEWasteImage(path);
    if (mounted && result != null) {
      setState(() {
        _selectedCategoryId = result.categoryId;
        _isAnalyzingAi = false;
        if (result.isMockResult) {
          _isAiSuggested = true;
        }
      });
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

    final minPriceRate = _selectedCategoryId == 'copper_wire' ? 450.0 : 280.0;
    final maxPriceRate = _selectedCategoryId == 'copper_wire' ? 620.0 : 420.0;
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
                      Text(loc.translate('analyzingAi')),
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
                      Text(
                        loc.translate('suggestedAi'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
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
