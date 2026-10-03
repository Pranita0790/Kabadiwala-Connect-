import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/kabadiwala_logo.dart';

class HomeScreen extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  final Locale currentLocale;

  const HomeScreen({
    super.key,
    required this.onLanguageChanged,
    required this.currentLocale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController.instance;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kabadiwala Connect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/reminders'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: KabadiwalaLogo(
                  width: 120,
                  height: 120,
                  isCircular: true,
                  padding: EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.translate('welcomeLandingTitle'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sell your scrap easily. Connect with nearby Kabadiwalas.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildActionCard(
                context: context,
                icon: Icons.search,
                title: 'Find Kabadiwala',
                subtitle: 'Search and connect with nearby vendors',
                onTap: () => Navigator.pushNamed(context, '/kabadiwala/find'),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context: context,
                icon: Icons.sell_outlined,
                title: 'Sell Scrap',
                subtitle: 'Select materials and request pickup',
                onTap: () => Navigator.pushNamed(context, '/materials/select'),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context: context,
                icon: Icons.group_outlined,
                title: 'My Kabadiwala',
                subtitle: 'View your connected kabadiwala',
                onTap: () => Navigator.pushNamed(context, '/kabadiwala/my'),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context: context,
                icon: Icons.history,
                title: 'Collection History',
                subtitle: 'View your past pickups & collections',
                onTap: () => Navigator.pushNamed(context, '/history/collection'),
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context: context,
                icon: Icons.payment_outlined,
                title: 'Payment History',
                subtitle: 'View payments & transactions',
                onTap: () => Navigator.pushNamed(context, '/payment/history'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
