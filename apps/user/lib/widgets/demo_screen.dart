import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class DemoScreenItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  const DemoScreenItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
}

/// A lightweight preview for app flows whose live data/API is not connected.
class DemoScreen extends StatelessWidget {
  final String title;
  final String intro;
  final IconData icon;
  final List<DemoScreenItem> items;
  final String? actionLabel;

  const DemoScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.icon,
    required this.items,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(intro, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF8A6200)),
                SizedBox(width: 8),
                Expanded(child: Text('Demo preview · Sample information only')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(item.icon, color: AppColors.primary),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item.subtitle),
                  trailing: item.trailing == null
                      ? null
                      : Text(item.trailing!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              )),
          if (actionLabel != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This action will be available when the service is connected.')),
                ),
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
