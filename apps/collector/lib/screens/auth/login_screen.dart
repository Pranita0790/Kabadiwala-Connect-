import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/kabadiwala_logo.dart';
import '../../widgets/language_selector.dart';
import 'otp_verification_screen.dart';
import 'sign_up_screen.dart';

/// Sign-in screen for an existing collector.
///
/// Phone number only. The SMS code is requested from Firebase and entered on
/// the next screen; the backend resolves that number to an account.
/// Collectors have no password — Firebase owns the SMS.
class LoginScreen extends StatefulWidget {
  final AuthController? authController;
  final Function(Locale)? onLanguageChanged;

  const LoginScreen({
    super.key,
    this.authController,
    this.onLanguageChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthController _authController;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Ask Firebase to text a code, then move to code entry.
  ///
  /// Sign-in and sign-up are the same flow: the phone number is the identity.
  /// The backend links the number to an existing account, or creates one, so
  /// there is no separate "login" path to keep in step with "sign up".
  Future<void> _handleLogin() async {
    final loc = AppLocalizations.of(context);
    final rawPhone = _phoneController.text.trim();

    final phoneError = AuthService.validateIndianMobile(rawPhone);
    if (phoneError != null) {
      setState(() {
        _errorMessage = loc.translate('validMobileError');
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final sent = await _authController.sendOtp(rawPhone);

      if (!mounted) return;

      if (sent) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: rawPhone,
              authController: _authController,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = _authController.errorMessage != null
              ? loc.translate(_authController.errorMessage!)
              : loc.translate('authErrorSendFailed');
        });
      }
    } catch (error) {
      developer.log(
        'Sign-in request failed',
        name: 'collector.auth',
        error: error,
      );

      if (mounted) {
        setState(() {
          _errorMessage = loc.translate('authErrorUnknown');
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          LanguageSelectorMenu(
            controller: LocaleController.instance,
            onLanguageChanged: widget.onLanguageChanged ?? (l) => LocaleController.instance.setLocale(l),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo & Welcome Header
              Center(
                child: Column(
                  children: [
                    const KabadiwalaLogo(
                      width: 80,
                      height: 80,
                      isCircular: true,
                      padding: EdgeInsets.all(6.0),
                      elevation: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('welcomeBackLogin'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.translate('loginToContinue'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Login Input Form Card
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _errorMessage != null ? AppColors.error : AppColors.primary.withAlpha(40),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mobile Number Label
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('mobileNumber'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Mobile Number Input Field (+91 + 10 Digits)
                      Row(
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12, width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              children: [
                                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: TextField(
                                key: const Key('login_phone_field'),
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: loc.translate('enterMobileNumber'),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    letterSpacing: 0.5,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Colors.black12, width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Colors.black12, width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),


                      // Error message if any
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
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
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Send the code. This is the only action: Firebase sends the SMS
              // and the next screen takes the code.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  key: const Key('login_send_code_btn'),
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          loc.translate('sendOtp'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // Link to Create Account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loc.translate('dontHaveAccount'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: const Key('login_go_to_signup_btn'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: Text(
                      loc.translate('createAccount'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
