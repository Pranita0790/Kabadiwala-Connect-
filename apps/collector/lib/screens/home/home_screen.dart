import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/utils/formatters.dart';
import '../../models/e_waste_lot.dart';
import '../../repositories/lot_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/kabadiwala_logo.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/sync_badge.dart';
import '../../widgets/sync_status_bar.dart';

class HomeScreen extends StatefulWidget {
  final Function(Locale) onLanguageChanged;
  final Locale currentLocale;
  final LotRepository? lotRepository;
  final TransactionRepository? transactionRepository;
  final SyncService? syncService;
  final ConnectivityService? connectivityService;
  final NotificationService? notificationService;
  final AuthController? authController;

  const HomeScreen({
    super.key,
    required this.onLanguageChanged,
    required this.currentLocale,
    this.lotRepository,
    this.transactionRepository,
    this.syncService,
    this.connectivityService,
    this.notificationService,
    this.authController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LotRepository _lotRepository;
  late final TransactionRepository _transactionRepository;
  late final SyncService _syncService;
  late final ConnectivityService _connectivityService;
  late final NotificationService _notificationService;
  late final AuthController _authController;

  List<EWasteLot> _lots = [];
  double _totalEarnings = 0.0;
  int _unreadNotificationCount = 0;
  bool _isLoading = false;
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<SyncStatus>? _syncSub;
  StreamSubscription<int>? _unreadNotifSub;

  @override
  void initState() {
    super.initState();
    _lotRepository = widget.lotRepository ?? LotRepository();
    _transactionRepository = widget.transactionRepository ?? TransactionRepository();
    _syncService = widget.syncService ?? SyncService.getInstance();
    _connectivityService = widget.connectivityService ?? ConnectivityService.instance;
    _notificationService = widget.notificationService ?? NotificationService.instance;
    _authController = widget.authController ?? AuthController.instance;
    _initListeners();
    _loadData();
  }

  void _initListeners() {
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });

    _unreadNotifSub = _notificationService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });

    _syncSub = _syncService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
        if (status == SyncStatus.synced || status == SyncStatus.failed) {
          _loadLots();
        }
      }
    });

    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final online = await _connectivityService.isConnected();
    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }
  }

  Future<void> _loadData() async {
    await _loadLots();
    await _loadEarnings();
    await _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLots() async {
    try {
      final list = await _lotRepository.getLots();
      if (mounted) {
        setState(() {
          _lots = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final ledger = await _transactionRepository.fetchTransactions();
      if (mounted) {
        setState(() {
          _totalEarnings = ledger.totalEarnings;
        });
      }
    } catch (_) {}
  }

  void _openRecyclerMatching() {
    Navigator.pushNamed(
      context,
      '/recyclers',
      arguments: _lots.isNotEmpty ? _lots.first : null,
    );
  }

  Future<void> _triggerManualSync() async {
    final result = await _syncService.syncPendingRecords();
    await _loadLots();
    await _loadEarnings();
    if (!mounted) return;
    if (result.failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _syncService.lastError ??
                'Sync failed. Sign in and keep the backend running on port 5000.',
          ),
          backgroundColor: AppColors.syncFailed,
        ),
      );
    }
  }

  int get _pendingCount => _lots.where((l) =>
      l.syncStatus == AppConstants.syncPending ||
      l.syncStatus == AppConstants.syncFailed).length;

  void _showAboutDialog(BuildContext context, AppLocalizations loc) {
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
                // 1. Header / Branding
                const KabadiwalaLogo(
                  width: 76,
                  height: 76,
                  isCircular: true,
                  padding: EdgeInsets.all(6.0),
                  elevation: 3,
                  fit: BoxFit.contain,
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

                // 2. Short App Description
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
                const SizedBox(height: 16),

                // 3. Key Features Section ("What you can do")
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.translate('whatYouCanDo'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildAboutFeatureRow(
                  icon: Icons.recycling_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  iconBg: const Color(0xFFE8F5E9),
                  title: loc.translate('featureMaterialManagement'),
                  desc: loc.translate('featureMaterialManagementDesc'),
                ),
                _buildAboutFeatureRow(
                  icon: Icons.price_change_rounded,
                  iconColor: const Color(0xFFE65100),
                  iconBg: const Color(0xFFFFF3E0),
                  title: loc.translate('featurePriceBoard'),
                  desc: loc.translate('featurePriceBoardDesc'),
                ),
                _buildAboutFeatureRow(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFF1565C0),
                  iconBg: const Color(0xFFE3F2FD),
                  title: loc.translate('featureFindRecyclers'),
                  desc: loc.translate('featureFindRecyclersDesc'),
                ),
                _buildAboutFeatureRow(
                  icon: Icons.qr_code_rounded,
                  iconColor: const Color(0xFF6A1B9A),
                  iconBg: const Color(0xFFF3E5F5),
                  title: loc.translate('featureSafeHandover'),
                  desc: loc.translate('featureSafeHandoverDesc'),
                ),
                _buildAboutFeatureRow(
                  icon: Icons.health_and_safety_rounded,
                  iconColor: const Color(0xFFC62828),
                  iconBg: const Color(0xFFFFEBEE),
                  title: loc.translate('featureSafetyGuidance'),
                  desc: loc.translate('featureSafetyGuidanceDesc'),
                ),
                _buildAboutFeatureRow(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF00695C),
                  iconBg: const Color(0xFFE0F2F1),
                  title: loc.translate('featureEarnings'),
                  desc: loc.translate('featureEarningsDesc'),
                ),
                const SizedBox(height: 12),

                // 4. Offline-First Highlight
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.translate('worksOffline'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.translate('worksOfflineDesc'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade900,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Languages
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.translate_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      loc.translate('availableLanguages'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 6. Version (Clean without SIH26229)
                Text(
                  loc.translate('versionInfo'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            child: Text(loc.translate('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutFeatureRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActiveLanguageCode(BuildContext context) {
    final ctrlCode = LocaleController.normalizeCode(LocaleController.instance.currentLanguageCode);
    if (ctrlCode == 'hi' || ctrlCode == 'mr') {
      return ctrlCode;
    }
    if (ctrlCode == 'en') {
      return 'en';
    }
    try {
      final locCode = Localizations.localeOf(context).languageCode;
      return LocaleController.normalizeCode(locCode);
    } catch (_) {
      return 'en';
    }
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations loc) {
    final activeCode = _getActiveLanguageCode(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(loc.translate('language')),
          ],
        ),
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
                await LocaleController.instance.setLanguageCode(normalized);
                widget.onLanguageChanged(Locale(normalized, ''));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppLocalizations loc) {
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
                  '/login',
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
  void dispose() {
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    _unreadNotifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          loc.translate('appTitle'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotificationCount > 0,
              label: Text(
                '$_unreadNotificationCount',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              child: const Icon(Icons.notifications_rounded),
            ),
            tooltip: loc.translate('notifications'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/notifications');
              _loadNotificationCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, size: 28),
            tooltip: loc.translate('profile'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/profile');
              if (mounted) setState(() {});
            },
          ),
          LanguageSelectorMenu(
            controller: LocaleController.instance,
            onLanguageChanged: widget.onLanguageChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const KabadiwalaLogo(
                        width: 52,
                        height: 52,
                        isCircular: true,
                        padding: EdgeInsets.all(4.0),
                        elevation: 2,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authController.currentUser?.name.isNotEmpty == true
                                  ? _authController.currentUser!.name
                                  : loc.translate('appTitle'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _authController.currentUser?.formattedPhone.isNotEmpty == true
                                  ? _authController.currentUser!.formattedPhone
                                  : loc.translate('appTagline'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_rounded, color: AppColors.primary),
                    title: Text(
                      loc.translate('home'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    selected: true,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('myLots')),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/create-lot');
                      _loadLots();
                      _loadEarnings();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.recycling_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('findRecycler')),
                    onTap: () {
                      Navigator.pop(context);
                      _openRecyclerMatching();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('earnings')),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/earnings');
                      _loadEarnings();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.price_change_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('priceBoard')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/prices');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('handover')),
                    onTap: () {
                      Navigator.pop(context);
                      if (_lots.isNotEmpty) {
                        Navigator.pushNamed(
                          context,
                          '/recyclers',
                          arguments: _lots.first,
                        );
                      } else {
                        _openRecyclerMatching();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('safety')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/safety');
                    },
                  ),
                  ListTile(
                    leading: Badge(
                      isLabelVisible: _unreadNotificationCount > 0,
                      label: Text(
                        '$_unreadNotificationCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      child: const Icon(Icons.notifications_rounded, color: AppColors.textPrimary),
                    ),
                    title: Text(loc.translate('notifications')),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/notifications');
                      _loadNotificationCount();
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('language')),
                    trailing: Text(
                      LocaleController.supportedLanguages
                          .firstWhere(
                            (l) => l.code == _getActiveLanguageCode(context),
                            orElse: () => LocaleController.supportedLanguages.first,
                          )
                          .nativeName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageDialog(context, loc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('profile')),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(context, '/profile');
                      if (mounted) setState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.textPrimary),
                    title: Text(loc.translate('aboutApp')),
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context, loc);
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: Text(
                      loc.translate('logout'),
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context, loc);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLots();
          await _loadEarnings();
          if (_isOnline) {
            await _triggerManualSync();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real-time Sync Status Bar
              SyncStatusBar(
                status: _syncStatus,
                isOnline: _isOnline,
                pendingCount: _pendingCount,
                onSyncPressed: _triggerManualSync,
              ),
              const SizedBox(height: 16),

              // Total Earnings Summary Card
              Card(
                color: AppColors.primaryDark,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('totalEarnings'),
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.currency(_totalEarnings),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${loc.translate('recordedLots')}: ${_lots.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          if (_pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.syncPending,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${loc.translate('pendingSync')}: $_pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Primary Action: Create Material Lot
              CustomButton(
                label: loc.translate('createLot'),
                icon: Icons.add_a_photo,
                onPressed: () async {
                  await Navigator.pushNamed(context, '/camera');
                  _loadLots();
                  _loadEarnings();
                },
              ),
              const SizedBox(height: 12),

              // Quick Actions Row 1: Recycler Matching & Safety Guidance
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      label: loc.translate('findRecycler'),
                      icon: Icons.location_searching_rounded,
                      isSecondary: true,
                      onPressed: _openRecyclerMatching,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: loc.translate('safety'),
                      icon: Icons.health_and_safety_rounded,
                      isSecondary: true,
                      onPressed: () => Navigator.pushNamed(context, '/safety'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Actions Row 2: Price Board & Earnings Ledger
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      label: loc.translate('priceBoard'),
                      icon: Icons.price_change,
                      isSecondary: true,
                      onPressed: () => Navigator.pushNamed(context, '/prices'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: loc.translate('earningsLedger'),
                      icon: Icons.account_balance_wallet,
                      isSecondary: true,
                      onPressed: () => Navigator.pushNamed(context, '/earnings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Lots Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.translate('recordedLots'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_pendingCount > 0 && _isOnline)
                    TextButton.icon(
                      onPressed: _triggerManualSync,
                      icon: const Icon(Icons.sync, size: 18, color: AppColors.primary),
                      label: Text(
                        loc.translate('syncNow'),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_lots.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.inbox, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          loc.translate('noLots'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lots.length,
                  itemBuilder: (context, index) {
                    final lot = _lots[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.recycling, color: AppColors.primary, size: 30),
                        ),
                        title: Text(
                          lot.categoryName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${Formatters.weight(lot.weightKg)} • ${lot.condition.toUpperCase()}'),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.priceRange(lot.estimatedMinPrice, lot.estimatedMaxPrice),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        trailing: SyncBadge(syncStatus: lot.syncStatus),
                        onTap: () async {
                          await Navigator.pushNamed(context, '/lot-details', arguments: lot);
                          _loadLots();
                          _loadEarnings();
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) async {
          switch (index) {
            case 0:
              // Home - already on home
              break;
            case 1:
              // Lots
              await Navigator.pushNamed(context, '/create-lot');
              _loadLots();
              _loadEarnings();
              break;
            case 2:
              // Recyclers
              _openRecyclerMatching();
              break;
            case 3:
              // Earnings
              await Navigator.pushNamed(context, '/earnings');
              _loadEarnings();
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: loc.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_rounded),
            label: loc.translate('lots'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.recycling_rounded),
            label: loc.translate('recyclers'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: loc.translate('earnings'),
          ),
        ],
      ),
    );
  }
}
