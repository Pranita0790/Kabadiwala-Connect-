import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/formatters.dart';
import '../models/price.dart';
import '../screens/prices/create_price_alert_dialog.dart';
import '../services/audio_service.dart';

class PriceCard extends StatefulWidget {
  final Price price;
  final String currentLanguage;
  final AudioService? audioService;

  const PriceCard({
    super.key,
    required this.price,
    required this.currentLanguage,
    this.audioService,
  });

  @override
  State<PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<PriceCard> {
  late final AudioService _audioService;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioService = widget.audioService ?? AudioService.getInstance();
  }

  Future<void> _handleListen() async {
    final localizedName = widget.price.getLocalizedName(widget.currentLanguage);
    setState(() => _isPlaying = true);

    await _audioService.speakPriceRange(
      material: localizedName,
      minPrice: widget.price.minPrice,
      maxPrice: widget.price.maxPrice,
      unit: widget.price.unit,
      languageCode: widget.currentLanguage,
    );

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  IconData _getCategoryIcon(String iconAsset) {
    switch (iconAsset) {
      case 'developer_board':
        return Icons.developer_board;
      case 'cable':
        return Icons.cable;
      case 'battery_charging_full':
        return Icons.battery_charging_full;
      case 'monitor':
        return Icons.monitor;
      case 'smartphone':
        return Icons.smartphone;
      case 'electrical_services':
        return Icons.electrical_services;
      default:
        return Icons.recycling;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localizedName = widget.price.getLocalizedName(widget.currentLanguage);
    final rangeText = Formatters.priceRange(widget.price.minPrice, widget.price.maxPrice);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14134233),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x08134233),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon, Material Name & Indicative Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14134233),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getCategoryIcon(widget.price.iconAsset),
                    size: 30,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Indicative Price Range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$rangeText / ${widget.price.unit}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2ECE5)),
            const SizedBox(height: 12),

            // Metadata Row: Location, Source & Last Updated
            Row(
              children: [
                // Location badge
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      widget.price.location,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Last Updated badge
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      loc.translate('updatedToday'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Source info
            Text(
              '${loc.translate('source')}: ${widget.price.source}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 14),

            // Action Buttons: Listen (TTS) & Set Alert
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _handleListen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlaying ? AppColors.accent : AppColors.surface,
                        foregroundColor: _isPlaying ? Colors.white : AppColors.primary,
                        elevation: _isPlaying ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      icon: Icon(
                        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
                        size: 26,
                        color: _isPlaying ? Colors.white : AppColors.primary,
                      ),
                      label: Text(
                        _isPlaying ? loc.translate('listening') : loc.translate('listen'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isPlaying ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showSetPriceAlertDialog(
                          context,
                          material: localizedName,
                          currentPrice: widget.price.maxPrice,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_alert_rounded, size: 20),
                      label: Text(
                        loc.translate('priceAlert'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
