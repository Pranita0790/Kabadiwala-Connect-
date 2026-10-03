import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/kabadiwala_logo.dart';

/// Clean, visual Onboarding walkthrough screen.
/// Summarizes key capabilities for newly onboarded kabadiwalas in simple terms.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final features = [
      const _OnboardingFeature(
        icon: Icons.inventory_2_rounded,
        iconColor: AppColors.primary,
        titleKey: 'onboardingStep1Title',
        descKey: 'onboardingStep1Desc',
      ),
      _OnboardingFeature(
        icon: Icons.price_change_rounded,
        iconColor: Colors.amber.shade800,
        titleKey: 'onboardingStep2Title',
        descKey: 'onboardingStep2Desc',
      ),
      const _OnboardingFeature(
        icon: Icons.recycling_rounded,
        iconColor: AppColors.secondary,
        titleKey: 'onboardingStep3Title',
        descKey: 'onboardingStep3Desc',
      ),
      _OnboardingFeature(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: Colors.teal.shade700,
        titleKey: 'onboardingStep4Title',
        descKey: 'onboardingStep4Desc',
      ),
      const _OnboardingFeature(
        icon: Icons.qr_code_scanner_rounded,
        iconColor: AppColors.primaryDark,
        titleKey: 'onboardingStep5Title',
        descKey: 'onboardingStep5Desc',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: () => _navigateToHome(context),
            child: Text(
              loc.translate('skip'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  children: [
                    const KabadiwalaLogo(
                      width: 72,
                      height: 72,
                      isCircular: true,
                      padding: EdgeInsets.all(6.0),
                      elevation: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('welcomeOnboarding'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('onboardingSubtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Feature cards
                    ...features.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: f.iconColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(f.icon, color: f.iconColor, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.translate(f.titleKey),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      loc.translate(f.descKey),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: CustomButton(
                label: loc.translate('getStarted'),
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => _navigateToHome(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingFeature {
  final IconData icon;
  final Color iconColor;
  final String titleKey;
  final String descKey;

  const _OnboardingFeature({
    required this.icon,
    required this.iconColor,
    required this.titleKey,
    required this.descKey,
  });
}
