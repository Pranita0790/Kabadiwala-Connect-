import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/locale_controller.dart';

class LanguageSelectorMenu extends StatelessWidget {
  final LocaleController? controller;
  final ValueChanged<Locale>? onLanguageChanged;

  const LanguageSelectorMenu({
    super.key,
    this.controller,
    this.onLanguageChanged,
  });

  String _resolveActiveCode(BuildContext context, LocaleController ctrl) {
    final ctrlCode = LocaleController.normalizeCode(ctrl.currentLanguageCode);
    if (ctrlCode == 'hi' || ctrlCode == 'mr') {
      return ctrlCode;
    }
    if (ctrlCode == 'en') {
      return 'en';
    }
    try {
      final locCode = Localizations.localeOf(context).languageCode;
      return LocaleController.normalizeCode(locCode);
    } catch (_) {
      return 'en';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? LocaleController.instance;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return PopupMenuButton<String>(
          tooltip: 'Change Language / भाषा बदलें / भाषा बदला',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, color: Colors.white, size: 22),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
              ],
            ),
          ),
          onSelected: (langCode) async {
            final normalized = LocaleController.normalizeCode(langCode);
            await ctrl.setLanguageCode(normalized);
            onLanguageChanged?.call(Locale(normalized, ''));
          },
          itemBuilder: (menuContext) {
            final activeCode = _resolveActiveCode(menuContext, ctrl);
            return LocaleController.supportedLanguages.map((lang) {
              final isSelected = lang.code == activeCode;
              return PopupMenuItem<String>(
                value: lang.code,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
