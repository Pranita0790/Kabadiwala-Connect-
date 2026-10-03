import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../models/user_profile.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../widgets/kabadiwala_logo.dart';
import '../../services/backend_url.dart';

/// Clean, high-contrast Profile Screen designed for informal scrap collectors.
/// Shows user info, language switch, notifications, safety, helpline, and logout.
class ProfileScreen extends StatefulWidget {
  final AuthController? authController;
  final LocaleController? localeController;
  final LotRepository? lotRepository;
  final TransactionRepository? transactionRepository;
  final Function(Locale)? onLanguageChanged;

  const ProfileScreen({
    super.key,
    this.authController,
    this.localeController,
    this.lotRepository,
    this.transactionRepository,
    this.onLanguageChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthController _authController;
  late final LocaleController _localeController;
  late final LotRepository _lotRepository;
  late final TransactionRepository _transactionRepository;

  int _lotsCount = 0;
  double _totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
    _localeController = widget.localeController ?? LocaleController.instance;
    _lotRepository = widget.lotRepository ?? LotRepository();
    _transactionRepository = widget.transactionRepository ?? TransactionRepository();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final lots = await _lotRepository.getLots();
      final ledger = await _transactionRepository.fetchTransactions();
      if (mounted) {
        setState(() {
          _lotsCount = lots.length;
          _totalEarnings = ledger.totalEarnings;
        });
      }
    } catch (_) {}
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations loc) {
    final activeCode = _localeController.currentLanguageCode;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(loc.translate('selectLanguage')),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocaleController.supportedLanguages.map((lang) {
            final isSelected = lang.code == activeCode;
            return ListTile(
              title: Text(
                lang.nativeName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              subtitle: Text(lang.englishName),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () async {
                final normalized = LocaleController.normalizeCode(lang.code);
                await _localeController.setLanguageCode(normalized);
                if (widget.onLanguageChanged != null) {
                  widget.onLanguageChanged!(Locale(normalized, ''));
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                setState(() {});
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.translate('close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(loc.translate('helpSupport'), style: const TextStyle(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.translate('helpline'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              loc.translate('helplineDesc'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_in_talk_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '1800-267-3329',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KabadiwalaLogo(
                  width: 76,
                  height: 76,
                  isCircular: true,
                  padding: EdgeInsets.all(6.0),
                  elevation: 3,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('appTitle'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  loc.translate('appTagline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    loc.translate('aboutAppDescription'),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(loc.translate('logoutConfirmTitle')),
          ],
        ),
        content: Text(
          loc.translate('logoutConfirmMessage'),
          style: const TextStyle(fontSize: 15, height: 1.3),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(90, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _authController.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            child: Text(loc.translate('logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = _authController.currentUser ?? UserProfile.defaultCollector();
    final activeLanguage = LocaleController.supportedLanguages.firstWhere(
      (l) => l.code == _localeController.currentLanguageCode,
      orElse: () => LocaleController.supportedLanguages.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(loc.translate('profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          children: [
            // User Header Profile Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          backgroundImage: (user.photoPath != null &&
                                  !kIsWeb &&
                                  File(user.photoPath!).existsSync())
                              ? FileImage(File(user.photoPath!))
                              : null,
                          child: (user.photoPath == null ||
                                  (kIsWeb && user.photoPath != null) ||
                                  (!kIsWeb && !File(user.photoPath!).existsSync()))
                              ? Text(
                                  user.initials,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name.isNotEmpty ? user.name : 'Kabadiwala Collector',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: user.isRecycler
                                      ? AppColors.secondary.withValues(alpha: 0.12)
                                      : AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user.isRecycler
                                      ? loc.translate('recyclerRoleBadge')
                                      : loc.translate('collectorRoleBadge'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: user.isRecycler ? AppColors.secondary : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: AppColors.syncSuccess, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.formattedPhone,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (user.city.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: Colors.grey, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.city,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Fast Collector Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_lotsCount',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.translate('recordedLots'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 32, color: Colors.grey.shade300),
                        Column(
                          children: [
                            Text(
                              '₹${_totalEarnings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.syncSuccess,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.translate('totalEarnings'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Profile Actions List
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.edit_rounded,
                    iconColor: AppColors.primary,
                    title: loc.translate('editProfile'),
                    subtitle: 'Name, City, Photo',
                    onTap: () async {
                      await Navigator.pushNamed(context, '/edit-profile');
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.blue.shade700,
                    title: loc.translate('language'),
                    subtitle: '${activeLanguage.nativeName} (${activeLanguage.englishName})',
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    onTap: () => _showLanguageDialog(context, loc),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.notifications_rounded,
                    iconColor: Colors.amber.shade800,
                    title: loc.translate('notifications'),
                    subtitle: 'Price alerts & handover notices',
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.assignment_rounded,
                    iconColor: Colors.deepOrange.shade700,
                    title: 'Pickup Requests',
                    subtitle: 'Customer pickups and collection',
                    onTap: () => Navigator.pushNamed(context, '/requests'),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.people_alt_rounded,
                    iconColor: Colors.brown.shade600,
                    title: 'Customers',
                    subtitle: 'Pickup history and amounts paid',
                    onTap: () => Navigator.pushNamed(context, '/customers'),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.sell_rounded,
                    iconColor: Colors.orange.shade800,
                    title: 'My Rate Card',
                    subtitle: 'Your collector rates for customers',
                    onTap: () => Navigator.pushNamed(context, '/my-rate-card'),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.health_and_safety_rounded,
                    iconColor: Colors.teal.shade700,
                    title: loc.translate('safety'),
                    subtitle: 'Safety guidance for handling e-waste',
                    onTap: () => Navigator.pushNamed(context, '/safety'),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.support_agent_rounded,
                    iconColor: Colors.indigo.shade700,
                    title: loc.translate('helpSupport'),
                    subtitle: 'Toll-free collector helpline',
                    onTap: () => _showHelpSupportDialog(context, loc),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.dns_rounded,
                    iconColor: Colors.blueGrey.shade700,
                    title: loc.translate('laptopServer'),
                    subtitle: BackendUrl.displayUrl,
                    onTap: () => _showServerUrlDialog(context, loc),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.grey.shade700,
                    title: loc.translate('aboutApp'),
                    subtitle: 'Version 1.0.0 • Offline-First',
                    onTap: () => _showAboutAppDialog(context, loc),
                  ),
                  const Divider(height: 1, indent: 64),

                  _buildProfileTile(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    title: loc.translate('logout'),
                    subtitle: 'Log out of current account',
                    titleColor: AppColors.error,
                    onTap: () => _confirmLogout(context, loc),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerUrlDialog(BuildContext context, AppLocalizations loc) async {
    final controller = TextEditingController(text: BackendUrl.displayUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.translate('laptopServer')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.translate('laptopServerHint')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'http://10.1.106.69:5000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.translate('save')),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await BackendUrl.saveOverride(controller.text);
      if (!context.mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('laptopServerSaved'))),
      );
    }
  }

  Widget _buildProfileTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
