import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/audio_service.dart';

class SafetyScreen extends StatefulWidget {
  final AudioService? audioService;

  const SafetyScreen({super.key, this.audioService});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  late final AudioService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = widget.audioService ?? AudioService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final safetyItems = [
      _SafetyItem(
        icon: Icons.front_hand_rounded,
        titleKey: 'wearGloves',
        descKey: 'wearGlovesDesc',
        color: AppColors.primary,
        bgColor: const Color(0xFFE8F5E9),
      ),
      _SafetyItem(
        icon: Icons.battery_alert_rounded,
        titleKey: 'batteryWarning',
        descKey: 'batteryWarningDesc',
        color: AppColors.error,
        bgColor: const Color(0xFFFFEBEE),
      ),
      _SafetyItem(
        icon: Icons.local_fire_department_rounded,
        titleKey: 'doNotBurn',
        descKey: 'doNotBurnDesc',
        color: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
      ),
      _SafetyItem(
        icon: Icons.warning_amber_rounded,
        titleKey: 'avoidLeaking',
        descKey: 'avoidLeakingDesc',
        color: const Color(0xFFC2185B),
        bgColor: const Color(0xFFFCE4EC),
      ),
      _SafetyItem(
        icon: Icons.inventory_2_rounded,
        titleKey: 'isolateDamaged',
        descKey: 'isolateDamagedDesc',
        color: const Color(0xFF512DA8),
        bgColor: const Color(0xFFEDE7F6),
      ),
      _SafetyItem(
        icon: Icons.verified_user_rounded,
        titleKey: 'authorizedOnly',
        descKey: 'authorizedOnlyDesc',
        color: AppColors.secondary,
        bgColor: const Color(0xFFE0F2F1),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('safetyFirst')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.health_and_safety_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('safetyFirst'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.translate('safety'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...safetyItems.map((item) {
            final title = loc.translate(item.titleKey);
            final desc = loc.translate(item.descKey);
            return _SafetyCard(
              icon: item.icon,
              title: title,
              desc: desc,
              color: item.color,
              bgColor: item.bgColor,
              onListen: () {
                _audioService.speak(
                  '$title. $desc',
                  languageCode: loc.locale.languageCode,
                );
              },
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SafetyItem {
  final IconData icon;
  final String titleKey;
  final String descKey;
  final Color color;
  final Color bgColor;

  _SafetyItem({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.color,
    required this.bgColor,
  });
}

class _SafetyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final Color bgColor;
  final VoidCallback onListen;

  const _SafetyCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.bgColor,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
              onPressed: onListen,
              tooltip: 'Listen',
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}
