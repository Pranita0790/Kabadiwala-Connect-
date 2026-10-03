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
