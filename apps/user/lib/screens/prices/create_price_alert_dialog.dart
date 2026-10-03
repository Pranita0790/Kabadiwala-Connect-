import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/notification_service.dart';

Future<void> showSetPriceAlertDialog(
  BuildContext context, {
  required String material,
  required double currentPrice,
}) async {
  final loc = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final controller = TextEditingController(
    text: (currentPrice * 1.1).round().toString(),
  );

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.add_alert_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              loc.translate('setPriceAlert'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${loc.translate('material')}: $material',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              '${loc.translate('indicativePrice')}: ₹${currentPrice.toStringAsFixed(0)}/kg',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('alertWhenReaches'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹ ',
                suffixText: '/ kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('cancel') == 'cancel' ? 'Cancel' : loc.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = double.tryParse(controller.text.trim());
              if (target != null && target > 0) {
                await NotificationService.instance.createPriceAlert(
                  material: material,
                  targetPrice: target,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text('Price alert set for $material at ₹${target.toStringAsFixed(0)}/kg'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(loc.translate('save')),
          ),
        ],
      );
    },
  );
}
