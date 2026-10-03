import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/kabadiwala_logo.dart';
import '../../widgets/language_selector.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

/// Dedicated Sign Up screen for new user registration.
/// Collects user details and initiates OTP verification for account creation.
class SignUpScreen extends StatefulWidget {
  final AuthController? authController;
  final Function(Locale)? onLanguageChanged;

  const SignUpScreen({
    super.key,
    this.authController,
    this.onLanguageChanged,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final AuthController _authController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _cityFocusNode = FocusNode();

  String _selectedRole = 'collector';
  String? _errorMessage;
  bool _isLoading = false;

  final List<String> _suggestedCities = [
    'Pune',
    'Mumbai',
    'Nagpur',
    'Nashik',
    'Thane',
    'Aurangabad',
  ];

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();

    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _cityFocusNode.dispose();

    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    final loc = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    // 1. Validation
    if (name.isEmpty) {
      setState(() => _errorMessage = loc.translate('nameRequiredError'));
      return;
    }

    final phoneError = AuthService.validateIndianMobile(rawPhone);
    if (phoneError != null) {
      setState(() => _errorMessage = loc.translate('validMobileError'));
      return;
    }

    if (city.isEmpty) {
      setState(() => _errorMessage = loc.translate('cityRequiredError'));
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      /*
       | No local "does this number exist" check.
       |
       | It used to run against SQLite, which cannot know about accounts
       | registered on another device, so it was both wrong and a way to
       | enumerate who was signed up. The backend is the only authority on
       | whether a number exists, and it links the account silently on
       | sign-in.
       */
      await _authController.initiateSignUp(
        name: name,
        phoneNumber: rawPhone,
        city: city,
        role: _selectedRole,
      );

      if (!mounted) return;

      if (_authController.errorMessage == null) {
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
          _errorMessage = loc.translate(_authController.errorMessage!);
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
              // Header
              Center(
                child: Column(
                  children: [
                    const KabadiwalaLogo(
                      width: 72,
                      height: 72,
                      isCircular: true,
                      padding: EdgeInsets.all(6.0),
                      elevation: 2,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      loc.translate('createYourAccount'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.translate('joinKabadiwala'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Container Card
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _errorMessage != null ? AppColors.error : AppColors.primary.withAlpha(35),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Full Name
                      _buildFieldLabel(loc.translate('fullName'), Icons.person_rounded),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('signup_name_field'),
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(loc.translate('enterFullName')),
                        onChanged: (_) => _clearError(),
                      ),

                      const SizedBox(height: 16),

                      // 2. Mobile Number
                      _buildFieldLabel(loc.translate('mobileNumber'), Icons.phone_android_rounded),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12, width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              children: [
                                Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 4),
                                Text(
                                  '+91',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: TextField(
                                key: const Key('signup_phone_field'),
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                decoration: _buildInputDecoration(loc.translate('enterMobileNumber')).copyWith(counterText: ''),
                                onChanged: (_) => _clearError(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 3. Area / City
                      _buildFieldLabel(loc.translate('cityArea'), Icons.location_city_rounded),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('signup_city_field'),
                        controller: _cityController,
                        focusNode: _cityFocusNode,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(loc.translate('enterCityArea')),
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 8),

                      // City Quick Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _suggestedCities.map((cityName) {
                          final isSelected = _cityController.text.trim().toLowerCase() == cityName.toLowerCase();
                          return ChoiceChip(
                            label: Text(cityName, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withAlpha(40),
                            onSelected: (selected) {
                              setState(() {
                                _cityController.text = cityName;
                                _clearError();
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // 6. Role Selection
                      _buildFieldLabel(loc.translate('whatDoYouDo'), Icons.work_outline_rounded),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: loc.translate('scrapCollector'),
                              icon: Icons.recycling_rounded,
                              isSelected: _selectedRole == 'collector',
                              onTap: () => setState(() => _selectedRole = 'collector'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _RoleCard(
                              title: loc.translate('recyclerRole'),
                              icon: Icons.factory_rounded,
                              isSelected: _selectedRole == 'recycler',
                              onTap: () => setState(() => _selectedRole = 'recycler'),
                            ),
                          ),
                        ],
                      ),

                      // Error message if any
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withAlpha(60)),
                          ),
                          child: Row(
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // CTA: CREATE ACCOUNT
              CustomButton(
                key: const Key('signup_submit_btn'),
                label: loc.translate('createAccount').toUpperCase(),
                icon: Icons.arrow_forward_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleCreateAccount,
              ),

              const SizedBox(height: 16),

              // Link to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loc.translate('alreadyHaveAccount'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: const Key('signup_go_to_login_btn'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Text(
                      loc.translate('login'),
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

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(25) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.black12,
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
