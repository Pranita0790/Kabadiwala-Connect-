import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/auth/user_auth_controller.dart';
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
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _paymentRepo.addListener(_onRepoChange);
    _profileRepo.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _paymentRepo.removeListener(_onRepoChange);
    _profileRepo.removeListener(_onRepoChange);
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
              onPressed: () {
                UserAuthController().logout();
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
