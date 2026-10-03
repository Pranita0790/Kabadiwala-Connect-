import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/auth/user_auth_controller.dart';
import '../../repositories/loyalty_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/user_profile_repository.dart';
import 'edit_profile_screen.dart';
import '../gate_pass/gate_pass_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final PaymentRepository _paymentRepo = PaymentRepository();
  final UserProfileRepository _profileRepo = UserProfileRepository();
  final LoyaltyRepository _loyaltyRepo = LoyaltyRepository();
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _paymentRepo.addListener(_onRepoChange);
    _profileRepo.addListener(_onRepoChange);
    _loyaltyRepo.addListener(_onRepoChange);
    _loyaltyRepo.sync();
  }

  @override
  void dispose() {
    _paymentRepo.removeListener(_onRepoChange);
    _profileRepo.removeListener(_onRepoChange);
    _loyaltyRepo.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileRepo.profile;
    final totalRecycledKg = _paymentRepo.totalWeightRecycled;
    final totalEarnedAmount = _paymentRepo.totalEarned;
    final co2SavedKg = (totalRecycledKg * 1.28);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile.name.isNotEmpty ? profile.name[0] : 'A',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.societyName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Dynamic Eco Impact Dashboard
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E382B), Color(0xFF08261C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'YOUR ECO IMPACT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Icon(Icons.eco_rounded, color: AppColors.accent, size: 22),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildImpactItem('Scrap Recycled', '${totalRecycledKg.toStringAsFixed(1)} kg', Icons.recycling),
                      _buildImpactItem('CO2 Saved', '${co2SavedKg.toStringAsFixed(1)} kg', Icons.cloud_done_outlined),
                      _buildImpactItem('Total Earned', '₹${totalEarnedAmount.toStringAsFixed(0)}', Icons.currency_rupee),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Invite friends · earn ₹20 each'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your code: ${_loyaltyRepo.referralCode ?? '…'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Credits ₹${_loyaltyRepo.creditsBalance.toStringAsFixed(0)} · '
                    'Referral earned ₹${_loyaltyRepo.referralEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loyaltyRepo.referralCode == null
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _loyaltyRepo.referralCode!),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Referral code copied')),
                                  );
                                },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy code'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApplyReferralSheet(),
                          icon: const Icon(Icons.add_card_outlined, size: 18),
                          label: const Text('Apply code'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Earnings & past sales'),
            const SizedBox(height: 8),
            _buildTileContainer([
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
                title: const Text('Payment / earnings history'),
                subtitle: Text(
                  '₹${totalEarnedAmount.toStringAsFixed(0)} total · ${_paymentRepo.transactionCount} sales',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.pushNamed(context, '/payment-history'),
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                title: const Text('Collection flow history'),
                subtitle: Text(
                  '${totalRecycledKg.toStringAsFixed(1)} kg recycled with kabadiwalas',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.pushNamed(context, '/collection-history'),
              ),
            ]),

            const SizedBox(height: 20),

            // Security & Pass Management
            _buildSectionHeader('Security & Society Access'),
            const SizedBox(height: 8),

            _buildTileContainer([
              ListTile(
                leading: const Icon(Icons.shield_rounded, color: AppColors.primary),
                title: const Text('Society Security Gate Pass'),
                subtitle: const Text('Generate & share pass via WhatsApp'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GatePassScreen()),
                  );
                },
              ),
            ]),

            const SizedBox(height: 20),

            // Menu Section: Account & Settings
            _buildSectionHeader('Account & Settings'),
            const SizedBox(height: 8),

            _buildTileContainer([
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                title: const Text('Saved Address'),
                subtitle: Text(profile.fullAddress),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                title: const Text('Preferred Payment Method'),
                subtitle: const Text('UPI (ananya@upi)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primary),
                title: const Text('App Language'),
                subtitle: Text(_selectedLanguage),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Hindi (हिंदी)', child: Text('हिंदी')),
                    DropdownMenuItem(value: 'Marathi (मराठी)', child: Text('मराठी')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedLanguage = val;
                      });
                    }
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                title: const Text('Pickup Notifications'),
                subtitle: const Text('Get alerts for driver arrival'),
                value: _notificationsEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
                },
              ),
            ]),

            const SizedBox(height: 20),

            _buildSectionHeader('Support & Legal'),
            const SizedBox(height: 8),

            _buildTileContainer([
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                title: const Text('Help & FAQs'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
                title: const Text('Privacy Policy & Terms'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 28),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () async {
                await UserAuthController().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: const Text('Log Out', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showApplyReferralSheet() async {
    final ctrl = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Apply referral code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'After your first scrap deal, you and your friend each get ₹20 credit.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code (KC-XXXX)',
                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    final ok = await _loyaltyRepo.applyReferralCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Referral code applied' : 'Could not apply referral code'),
      ),
    );
  }

  Widget _buildImpactItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTileContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
      ),
      child: Column(children: children),
    );
  }
}
