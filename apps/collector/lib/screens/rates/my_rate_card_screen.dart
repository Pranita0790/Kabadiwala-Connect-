import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/collector_rate.dart';
import '../../repositories/collector_rate_repository.dart';
import 'edit_rate_screen.dart';

class MyRateCardScreen extends StatefulWidget {
  const MyRateCardScreen({super.key});

  @override
  State<MyRateCardScreen> createState() => _MyRateCardScreenState();
}

class _MyRateCardScreenState extends State<MyRateCardScreen> {
  final CollectorRateRepository _repository = CollectorRateRepository();
  bool _isLoading = true;
  List<CollectorRate> _rates = [];

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);
    try {
      final rates = await _repository.getRates();
      setState(() {
        _rates = rates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRate(CollectorRate rate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rate'),
        content: Text('Are you sure you want to remove rate for "${rate.materialName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteRate(rate.id);
      _loadRates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: const Text('My Rate Card'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditRateScreen()),
          );
          _loadRates();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sell_outlined, size: 64, color: AppColors.primary.withAlpha(120)),
                      const SizedBox(height: 16),
                      const Text(
                        'No custom rates added yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRates,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rates.length,
                    itemBuilder: (context, index) {
                      final rate = _rates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(25),
                            child: Icon(
                              _getCategoryIcon(rate.materialCategory),
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            rate.materialName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                          subtitle: Text(
                            rate.materialCategory,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${rate.ratePerKg.toStringAsFixed(0)} / ${rate.unit}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.clayOrange,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditRateScreen(existingRate: rate),
                                      ),
                                    );
                                    _loadRates();
                                  } else if (value == 'delete') {
                                    _deleteRate(rate);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('e-waste') || lower.contains('electronics')) {
      return Icons.devices;
    } else if (lower.contains('metal')) {
      return Icons.build;
    } else if (lower.contains('battery')) {
      return Icons.battery_charging_full;
    } else if (lower.contains('paper')) {
      return Icons.description;
    } else {
      return Icons.recycling;
    }
  }
}
