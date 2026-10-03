import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/collection_record.dart';
import '../../repositories/collection_repository.dart';

class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  final CollectionRepository _repo = CollectionRepository();

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final collections = _repo.collections;
    final totalWeight = _repo.totalWeightKg;
    final totalAmount = _repo.totalIncome;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collection History'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Collections', '${collections.length}'),
                Container(height: 30, width: 1, color: AppColors.border),
                _buildStatColumn('Total Scrap', '${totalWeight.toStringAsFixed(1)} kg'),
                Container(height: 30, width: 1, color: AppColors.border),
                _buildStatColumn('Earned', '₹${totalAmount.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: collections.isEmpty
                ? const Center(
                    child: Text(
                      'No past collections yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      return _buildCollectionCard(collections[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionCard(CollectionRecord collection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.materialName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '₹${collection.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${collection.vendorName} · ${collection.formattedDate}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${collection.actualWeightKg.toStringAsFixed(1)} kg · ${collection.paymentStatus}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
