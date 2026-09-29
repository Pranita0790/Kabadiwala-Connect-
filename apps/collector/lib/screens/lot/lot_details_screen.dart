import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../models/e_waste_lot.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sync_badge.dart';

class LotDetailsScreen extends StatelessWidget {
  final EWasteLot lot;

  const LotDetailsScreen({super.key, required this.lot});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('lotDetails')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview if available
            if (lot.imagePath != null && File(lot.imagePath!).existsSync())
              Container(
                height: 180,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(lot.imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Top Status & Header Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lot.categoryName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SyncBadge(syncStatus: lot.syncStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Weight & Condition
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.translate('weight'),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.weight(lot.weightKg),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              loc.translate('condition'),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lot.condition.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Estimated Price Range
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.price_check_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.translate('estimatedValue'),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.priceRange(lot.estimatedMinPrice, lot.estimatedMaxPrice),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (lot.notes != null && lot.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        loc.translate('optionalNotes'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lot.notes!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            CustomButton(
              label: loc.translate('handoverToRecycler'),
              icon: Icons.handshake_rounded,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/recycler-handover',
                  arguments: lot,
                );
              },
            ),
            const SizedBox(height: 12),
            CustomButton(
              label: loc.translate('findRecycler'),
              icon: Icons.location_searching_rounded,
              isSecondary: true,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/recyclers',
                  arguments: lot,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: loc.translate('safety'),
                    icon: Icons.health_and_safety_rounded,
                    isSecondary: true,
                    onPressed: () => Navigator.pushNamed(context, '/safety'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: loc.translate('priceBoard'),
                    icon: Icons.price_change,
                    isSecondary: true,
                    onPressed: () => Navigator.pushNamed(context, '/prices'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
