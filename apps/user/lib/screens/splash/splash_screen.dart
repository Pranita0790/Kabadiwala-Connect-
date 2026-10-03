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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(flex: 2),
                // Prominent official logo with preserved aspect ratio and circular presentation
                KabadiwalaLogo(
                  width: 220,
                  height: 220,
                  isCircular: true,
                  padding: EdgeInsets.all(14.0),
                  elevation: 6,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 28),
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Connecting Collectors • Fair Prices • Formal Recycling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF558B2F),
                    height: 1.4,
                  ),
                ),
                Spacer(flex: 2),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                  strokeWidth: 3,
                ),
                Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
