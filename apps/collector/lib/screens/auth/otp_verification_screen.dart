import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/custom_button.dart';

/// Simple 6-digit OTP Verification Screen.
/// Low-literacy friendly with auto-advance digit boxes, 30s resend timer,
/// demo OTP autofill, and error handling.
class OtpVerificationScreen extends StatefulWidget {
  final String? phoneNumber;
  final AuthController? authController;

  const OtpVerificationScreen({
    super.key,
    this.phoneNumber,
    this.authController,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final AuthController _authController;
  late final String _targetPhone;

  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 30;
  Timer? _countdownTimer;
  bool _canResend = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
    _targetPhone = widget.phoneNumber ?? _authController.pendingPhoneNumber ?? '9876543210';
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _resendCountdown = 30;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _enteredOtp {
    return _digitControllers.map((c) => c.text.trim()).join();
  }

  void _fillDemoOtp() {
    const demo = '123456';
    for (int i = 0; i < 6; i++) {
      _digitControllers[i].text = demo[i];
    }
    setState(() {
      _errorMessage = null;
    });
    if (_focusNodes.last.canRequestFocus) {
      _focusNodes.last.requestFocus();
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend || _isLoading) return;
    final loc = AppLocalizations.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authController.sendOtp(_targetPhone);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.translate('otpSentTo')} $_formattedPhone'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
          _startCountdown();
        } else {
          setState(() {
            _errorMessage = _authController.errorMessage ?? 'Failed to resend OTP';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerify() async {
    final loc = AppLocalizations.of(context);
    final otp = _enteredOtp;

    if (otp.length != 6) {
      setState(() {
        _errorMessage = loc.translate('otpMustBe6Digits');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authController.verifyOtp(otp, phoneNumber: _targetPhone);

      if (!mounted) return;

      if (result.success) {
        if (result.isNewUser) {
          // Navigate to Profile Setup for new user
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/profile-setup',
            (route) => false,
          );
        } else {
          // Existing user -> Navigate to Home
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('loggedInSuccess')),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        }
      } else {
        setState(() {
          _errorMessage = loc.translate('incorrectOtp');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _formattedPhone {
    final digits = _targetPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return _targetPhone;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Shield Icon & Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                loc.translate('verifyMobileNumber'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                '${loc.translate('signUpOtpSubtitle')}\n\n$_formattedPhone',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    loc.translate('changeNumber'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 6 OTP Digit Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 58,
                    child: TextField(
                      controller: _digitControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black12, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _digitControllers[index].text.isNotEmpty
                                ? AppColors.primary
                                : Colors.black12,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2.2),
                        ),
                      ),
                      onChanged: (val) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                        if (val.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_enteredOtp.length == 6) {
                          _handleVerify();
                        }
                      },
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Demo OTP Quick Auto-fill Chip
              InkWell(
                onTap: _fillDemoOtp,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pin_rounded, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${loc.translate('demoOtpHide')} (Tap to fill)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP / Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_canResend) ...[
                    TextButton.icon(
                      onPressed: _handleResendOtp,
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                      label: Text(
                        loc.translate('resendOtp'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${loc.translate('resendIn')} $_resendCountdown ${loc.translate('seconds')}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),

              // Primary Action: Verify & Continue
              CustomButton(
                label: loc.translate('verifyAndContinue'),
                icon: Icons.check_circle_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleVerify,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
