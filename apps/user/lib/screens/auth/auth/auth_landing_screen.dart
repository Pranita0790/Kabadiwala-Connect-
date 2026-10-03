import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Language Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LanguageSelectorButton(),
                ],
              ),
              const Spacer(flex: 2),

              // App Logo / Hero Icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.recycling_rounded,
                    size: 54,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title and Subtitle
              Text(
                l10n.translate('namaste'),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('welcomeLandingTitle'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('welcomeLandingSubtitle'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // LOGIN CTA (Primary Button, Large 56px)
              ElevatedButton(
                key: const Key('landing_login_btn'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l10n.translate('login').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // CREATE ACCOUNT CTA (Secondary Outlined/Light Button, 56px)
              OutlinedButton(
                key: const Key('landing_signup_btn'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SignUpScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: AppColors.primary.withAlpha(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l10n.translate('createAccount').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSelectorButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final currentCode = LocaleController.instance.currentLocale.languageCode;
        return PopupMenuButton<String>(
          key: const Key('landing_language_btn'),
          initialValue: currentCode,
          onSelected: (code) {
            LocaleController.instance.setLocale(Locale(code));
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _getLanguageName(currentCode),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'en',
              child: Text('English'),
            ),
            const PopupMenuItem(
              value: 'hi',
              child: Text('हिंदी (Hindi)'),
            ),
            const PopupMenuItem(
              value: 'mr',
              child: Text('मराठी (Marathi)'),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      case 'en':
      default:
        return 'English';
    }
  }
}
