import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/material_item.dart';
import '../../models/sell_draft.dart';
import '../../models/vendor.dart';
import 'sell_cost_mode_screen.dart';

/// Step 2: user selects what scrap they have + approx weight (₹ by kg).
class SellMaterialsScreen extends StatefulWidget {
  final Vendor vendor;

  const SellMaterialsScreen({super.key, required this.vendor});

  @override
  State<SellMaterialsScreen> createState() => _SellMaterialsScreenState();
}

class _SellMaterialsScreenState extends State<SellMaterialsScreen> {
  final Set<String> _selectedIds = {};
  final Map<String, TextEditingController> _weightCtrls = {};

  @override
  void dispose() {
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String id) {
    return _weightCtrls.putIfAbsent(id, () => TextEditingController(text: '10'));
  }

  void _toggle(MaterialItem m) {
    setState(() {
      if (_selectedIds.contains(m.id)) {
        _selectedIds.remove(m.id);
      } else {
        _selectedIds.add(m.id);
        _ctrlFor(m.id);
      }
    });
  }

  void _continue() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one material you have')),
      );
      return;
    }

    final lines = <SellLineItem>[];
    for (final m in MaterialItem.defaultMaterials) {
      if (!_selectedIds.contains(m.id)) continue;
      final w = double.tryParse(_ctrlFor(m.id).text.trim()) ?? 0;
      if (w <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter weight (kg) for ${m.category}')),
        );
        return;
      }
      lines.add(SellLineItem(material: m, weightKg: w));
    }

    final draft = SellDraft(vendor: widget.vendor, lines: lines);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellCostModeScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('What scrap do you have?'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    v.name.isNotEmpty ? v.name[0] : 'K',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                title: Text(
                  v.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  v.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select materials & approx weight (payment by kg)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: MaterialItem.defaultMaterials.length,
              itemBuilder: (context, index) {
                final m = MaterialItem.defaultMaterials[index];
                final selected = _selectedIds.contains(m.id);
                final rate = v.ratesPerKg[m.category] ?? m.defaultRatePerKg;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _toggle(m),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: selected,
                                activeColor: AppColors.primary,
                                onChanged: (_) => _toggle(m),
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(m.icon, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '₹${rate.toStringAsFixed(0)} / kg · ${m.category}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (selected) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _ctrlFor(m.id),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Approx weight (kg)',
                                prefixIcon: const Icon(Icons.scale, color: AppColors.primary),
                                hintText: 'e.g. 12',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Select materials'
                      : 'See estimated cost (${_selectedIds.length})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
