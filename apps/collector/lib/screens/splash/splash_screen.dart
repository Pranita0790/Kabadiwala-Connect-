import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/kabadiwala_logo.dart';

/// Splash Screen displaying the official Kabadiwala Connect branding.
/// Designed with a clean light background, preserved aspect ratio,
/// and offline-first instantaneous initialization.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onInitializationComplete;
  final Duration duration;

  const SplashScreen({
    super.key,
    this.onInitializationComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.onInitializationComplete != null) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          widget.onInitializationComplete!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F870),
      body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Prominent official logo with preserved aspect ratio and circular presentation
                  const KabadiwalaLogo(
                    width: 220,
                    height: 220,
                    isCircular: true,
                    padding: EdgeInsets.all(14.0),
                    elevation: 8,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B2E21),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Connecting Collectors • Fair Prices • Formal Recycling',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B4D3B),
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 2),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B2E21)),
                    strokeWidth: 3.5,
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
