import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFD8F870),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar matching Screenshot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top-Left Brand Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x180E382B),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Kabadiwala Connect',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0E382B),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          _LanguageSelectorButton(),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Main Hero Title with Floating Clay Capsules (Stack)
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          final floatVal = _animController.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Editorial Headline
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 20, right: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fair price',
                                      style: TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0E382B),
                                        letterSpacing: -1.2,
                                        height: 1.05,
                                      ),
                                    ),
                                    Text(
                                      'for every',
                                      style: TextStyle(
                                        fontSize: 46,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'serif',
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF0E382B),
                                        letterSpacing: -0.8,
                                        height: 1.05,
                                      ),
                                    ),
                                    Text(
                                      'kabadiwala.',
                                      style: TextStyle(
                                        fontSize: 46,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'serif',
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF0E382B),
                                        letterSpacing: -0.8,
                                        height: 1.05,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Floating Clay Capsule: Battery (White)
                              Positioned(
                                top: 12 - (floatVal * 5),
                                right: 10,
                                child: _buildClayPill(
                                  text: 'Battery',
                                  bgColor: Colors.white,
                                  textColor: const Color(0xFF0E382B),
                                  shadowColor: const Color(0x220E382B),
                                ),
                              ),

                              // Floating Clay Capsule: Old phone (White)
                              Positioned(
                                top: 88 + (floatVal * 4),
                                right: -4,
                                child: _buildClayPill(
                                  text: 'Old phone',
                                  bgColor: Colors.white,
                                  textColor: const Color(0xFF0E382B),
                                  shadowColor: const Color(0x220E382B),
                                ),
                              ),

                              // Floating Clay Capsule: Laptop (Vivid Orange)
                              Positioned(
                                top: 155 - (floatVal * 4),
                                right: 60,
                                child: _buildClayPill(
                                  text: 'Laptop',
                                  bgColor: const Color(0xFFFF7836),
                                  textColor: Colors.white,
                                  shadowColor: const Color(0x40FF7836),
                                ),
                              ),

                              // Floating Clay Capsule: Circuit board (Pink)
                              Positioned(
                                bottom: 20 + (floatVal * 6),
                                right: -8,
                                child: _buildClayPill(
                                  text: 'Circuit board',
                                  bgColor: const Color(0xFFF43F5E),
                                  textColor: Colors.white,
                                  shadowColor: const Color(0x40F43F5E),
                                ),
                              ),

                              // Floating Clay Capsule: Charger (Warm Orange)
                              Positioned(
                                bottom: -22 - (floatVal * 5),
                                right: 65,
                                child: _buildClayPill(
                                  text: 'Charger',
                                  bgColor: const Color(0xFFFF7034),
                                  textColor: Colors.white,
                                  shadowColor: const Color(0x40FF7034),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Reference Subtitle text
                      const Text(
                        'A vernacular, offline-first platform that helps informal e-waste collectors identify material, discover fair value, meet authorized recyclers and keep proof of every handover.',
                        style: TextStyle(
                          color: Color(0xFF0E382B),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // CTA Button: "See how it works ●" / Login (Deep Forest Green Pill)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x380E382B),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                key: const Key('landing_login_btn'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E382B),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'See how it works',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD8F870),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sign Up Button Pill
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140E382B),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              key: const Key('landing_signup_btn'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0E382B),
                                minimumSize: const Size(110, 54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFF0E382B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Quick Demo Access Button
                      OutlinedButton.icon(
                        key: const Key('landing_demo_btn'),
                        onPressed: () async {
                          final ok = await AuthController.instance.signInAsDemoUser();
                          if (!context.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.translate('demoLoginFailed'))),
                            );
                          }
                        },
                        icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF0E382B), size: 18),
                        label: const Text(
                          'Quick Demo Access (Explore App & Backend)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E382B),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          side: const BorderSide(color: Color(0xFF0E382B), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          backgroundColor: Colors.white.withAlpha(120),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bottom Reference Metadata Pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetadataPill('Team Gurlypops'),
                          _buildMetadataPill('CSI Hackathon, Round 1'),
                          _buildMetadataPill('Domain: AI & ML'),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _buildClayPill({
    required String text,
    required Color bgColor,
    required Color textColor,
    required Color shadowColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  static Widget _buildMetadataPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0E382B), width: 1.2),
        color: Colors.white.withAlpha(60),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0E382B),
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
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180E382B),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLangTab('en', 'English', currentCode == 'en'),
              _buildLangTab('hi', 'हिंदी', currentCode == 'hi'),
              _buildLangTab('mr', 'मराठी', currentCode == 'mr'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLangTab(String code, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        LocaleController.instance.setLocale(Locale(code));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0E382B) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF0E382B),
          ),
        ),
      ),
    );
  }
}
