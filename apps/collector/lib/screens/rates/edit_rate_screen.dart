import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/collector_rate.dart';
import '../../repositories/collector_rate_repository.dart';

class EditRateScreen extends StatefulWidget {
  final CollectorRate? existingRate;

  const EditRateScreen({super.key, this.existingRate});

  @override
  State<EditRateScreen> createState() => _EditRateScreenState();
}

class _EditRateScreenState extends State<EditRateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CollectorRateRepository _repository = CollectorRateRepository();

  late String _selectedCategory;
  late TextEditingController _nameController;
  late TextEditingController _rateController;
  bool _isSaving = false;

  final List<String> _categories = [
    'E-Waste',
    'Metals',
    'Batteries',
    'Paper',
    'Plastics',
    'Glass',
    'Rubber & Tyres',
    'General Scrap',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.existingRate?.materialCategory ?? 'E-Waste';
    _nameController = TextEditingController(text: widget.existingRate?.materialName ?? '');
    _rateController = TextEditingController(
      text: widget.existingRate != null ? widget.existingRate!.ratePerKg.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _saveRate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final rateValue = double.parse(_rateController.text.trim());
      final rate = CollectorRate(
        id: widget.existingRate?.id ?? '',
        // Repository rewrites default_collector → logged-in publicId.
        collectorId:
            widget.existingRate?.collectorId ?? await _repository.resolveCollectorId(),
        materialCategory: _selectedCategory,
        materialName: _nameController.text.trim(),
        ratePerKg: rateValue,
        unit: 'kg',
      );

      await _repository.saveRate(rate);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate card updated successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRate != null;

    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Rate' : 'Add New Rate'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Material & Rate Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _categories.contains(_selectedCategory) ? _selectedCategory : _categories.first,
                        decoration: InputDecoration(
                          labelText: 'Material Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.category, color: AppColors.primary),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Material Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Material / Scrap Name',
                          hintText: 'e.g., Motherboards, Copper Wire',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.label, color: AppColors.primary),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter material name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Rate per Kg
                      TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Buying Rate per kg (₹)',
                          hintText: 'e.g., 120',
                          suffixText: '₹ / kg',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter rate per kg';
                          }
                          final parsed = double.tryParse(val);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive price';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRate,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(isEditing ? 'Update Rate' : 'Save Rate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
