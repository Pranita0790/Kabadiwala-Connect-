import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../services/ai_classification_service.dart';

/// On-screen Gemini result: item, category, confidence, and collector tips.
class AiInsightCard extends StatelessWidget {
  final ClassificationResult result;
  final bool compact;

  const AiInsightCard({
    super.key,
    required this.result,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final percent = (result.confidenceScore * 100).clamp(0, 100).round();
    final device = (result.electronicDevice ?? result.categoryName).trim();
    final tips = result.suggestions.isNotEmpty
        ? result.suggestions
        : _fallbackTips(result.categoryId);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFECF8F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.translate('aiAnalyzerTitle'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            device,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${loc.translate('aiMatchedCategory')}: ${result.categoryName}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result.ratePerKgInr != null || result.estimatedValueInr != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Rate',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${result.ratePerKgInr ?? '--'}/kg',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                      if (result.rateRange != null)
                        Text(
                          result.rateRange!,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  if (result.estimatedValueInr != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total Est. Value',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${result.estimatedValueInr}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (result.detectedMinerals.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Critical Minerals & Elements:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final min in result.detectedMinerals)
                  Chip(
                    label: Text(min, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                    backgroundColor: const Color(0xFFDCEDC8),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (result.eprCredits != null || result.co2SavedKg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco, color: Color(0xFF00796B), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'EPR: +${result.eprCredits ?? 0} pts  •  CO₂ Saved: ${result.co2SavedKg ?? 0} kg',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                  ),
                ],
              ),
            ),
          ],
          if (result.negotiationTip != null && result.negotiationTip!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFF59D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology, color: Color(0xFFF57F17), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Bargaining Tip: ${result.negotiationTip!}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((result.shortDescription ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.shortDescription!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              loc.translate('aiSuggestions'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 6),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontWeight: FontWeight.w800)),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static List<String> _fallbackTips(String categoryId) {
    switch (categoryId) {
      case 'battery':
        return const [
          'Tape the terminals and keep cells dry.',
          'Save this lot as Batteries, not mixed scrap.',
        ];
      case 'pcb_motherboard':
        return const [
          'This looks like a circuit board.',
          'Save as Motherboard / PCB for a better rate.',
        ];
      case 'copper_wire':
        return const [
          'Bundle copper wire separately from plastic.',
          'Save as Copper Wire on the lot form.',
        ];
      default:
        return const [
          'If unsure, choose Mixed E-Waste and add a photo note.',
          'An authorized recycler can re-check the category.',
        ];
    }
  }
}
