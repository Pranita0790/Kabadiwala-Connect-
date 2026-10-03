import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';

class NotificationsScreen extends StatefulWidget {
  final List<AppNotification>? initialNotifications;
  final NotificationService? notificationService;

  const NotificationsScreen({
    super.key,
    this.initialNotifications,
    this.notificationService,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _notificationService;
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService.instance;
    if (widget.initialNotifications != null) {
      _notifications = widget.initialNotifications!;
      _isLoading = false;
      _hasError = false;
    } else {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _notificationService.pullFromBackend();
      final list = await _notificationService.getNotifications().timeout(
        const Duration(seconds: 8),
        onTimeout: () => <AppNotification>[],
      );
      if (mounted) {
        setState(() {
          _notifications = list;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Notification loading error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
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

  void _onNotificationTapped(AppNotification item) {
    // Attempt background mark-as-read without blocking navigation
    unawaited(_notificationService.markAsRead(item.id));

    if (!mounted) return;

    if (item.type == AppConstants.notificationTypeHandover ||
        item.type == AppConstants.notificationHandover ||
        item.type == 'HANDOVER_CONFIRMED' ||
        item.type == 'LOT_STATUS') {
      Navigator.pushNamed(context, '/earnings');
    } else if (item.type == AppConstants.notificationTypePriceAlert ||
        item.type == AppConstants.notificationPriceAlert) {
      Navigator.pushNamed(context, '/prices');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      _loadNotifications();
    } catch (_) {}
  }

  Future<void> _triggerDemoPriceAlert() async {
    try {
      await _notificationService.triggerPriceAlertDemo(
        material: 'Copper Wire',
        targetPrice: 700.0,
        currentPrice: 720.0,
      );
      _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo Price Alert Triggered!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error triggering demo price alert: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final lang = loc.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          loc.translate('notifications'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                loc.translate('markAllRead'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          Expanded(
            child: _buildBody(loc, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc, String lang) {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                loc.translate('errorLoadingNotifications'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: loc.translate('retry'),
                icon: Icons.refresh,
                onPressed: _loadNotifications,
              ),
              const SizedBox(height: 24),
              _buildDemoCardsSection(loc),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Empty State Icon & Heading
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('noNotificationsYet'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                loc.translate('notificationEmptyDesc'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 24),
            // Two Interactive Demo Cards (Step 8)
            _buildDemoCardsSection(loc),
            const SizedBox(height: 16),
            // Demo Action Trigger Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _triggerDemoPriceAlert,
                icon: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                label: Text(
                  loc.translate('triggerPriceDemo'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade900,
                  side: BorderSide(color: Colors.amber.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final isHandover = item.type == AppConstants.notificationTypeHandover ||
            item.type == AppConstants.notificationHandover ||
            item.type == 'HANDOVER_CONFIRMED' ||
            item.type == 'LOT_STATUS';

        return Card(
          elevation: item.isRead ? 1 : 3,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: item.isRead
                  ? Colors.grey.shade200
                  : (isHandover ? AppColors.primary : Colors.amber.shade700),
              width: item.isRead ? 1 : 1.5,
            ),
          ),
          color: item.isRead
              ? Colors.white
              : (isHandover
                  ? const Color(0xFFF1F8E9)
                  : const Color(0xFFFFFDE7)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isHandover
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHandover
                    ? Icons.check_circle_rounded
                    : Icons.trending_up_rounded,
                color: isHandover
                    ? AppColors.primary
                    : Colors.amber.shade900,
                size: 24,
              ),
            ),
            title: Text(
              item.getTitle(lang),
              style: TextStyle(
                fontSize: 15,
                fontWeight: item.isRead
                    ? FontWeight.w600
                    : FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.getBody(lang),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(item.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: !item.isRead
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _onNotificationTapped(item),
          ),
        );
      },
    );
  }

  Widget _buildDemoCardsSection(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sample Alerts (Tap to Test Navigation):',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // 1. Price Alert Demo Card -> /prices
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.shade300),
          ),
          color: const Color(0xFFFFFDE7),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.trending_up_rounded, color: Colors.amber.shade900),
            ),
            title: Text(
              loc.translate('priceAlert') == 'priceAlert'
                  ? 'Price Alert: Copper Wire'
                  : '${loc.translate('priceAlert')}: Copper Wire',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'Copper Wire rate spiked to ₹720/kg (+8%). Tap to view Price Board.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            onTap: () {
              Navigator.pushNamed(context, '/prices');
            },
          ),
        ),
        // 2. Handover Confirmed Demo Card -> /earnings
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          color: const Color(0xFFF1F8E9),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
            ),
            title: Text(
              loc.translate('handoverConfirmed'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              '₹2,400 received from Recycler. Tap to view Earnings Ledger.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            onTap: () {
              Navigator.pushNamed(context, '/earnings');
            },
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
