import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../services/sync_service.dart';

/// Top status bar widget displaying real-time offline/online and sync states:
/// - Waiting for internet
/// - Syncing
/// - Synced
/// - Failed
class SyncStatusBar extends StatelessWidget {
  final SyncStatus status;
  final bool isOnline;
  final int pendingCount;
  final VoidCallback onSyncPressed;

  const SyncStatusBar({
    super.key,
    required this.status,
    required this.isOnline,
    required this.pendingCount,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String message;
    bool showSyncButton = false;

    if (!isOnline || status == SyncStatus.waitingForInternet) {
      bgColor = AppColors.syncPending.withValues(alpha: 0.12);
      borderColor = AppColors.syncPending;
      textColor = AppColors.syncPending;
      icon = Icons.wifi_off_rounded;
      message = '${loc.translate('waitingForInternet')} • ${loc.translate('offlineModeActive')}';
      showSyncButton = false;
    } else if (status == SyncStatus.syncing) {
      bgColor = AppColors.syncing.withValues(alpha: 0.12);
      borderColor = AppColors.syncing;
      textColor = AppColors.syncing;
      icon = Icons.sync_rounded;
      message = loc.translate('syncing');
      showSyncButton = false;
    } else if (status == SyncStatus.failed) {
      bgColor = AppColors.syncFailed.withValues(alpha: 0.12);
      borderColor = AppColors.syncFailed;
      textColor = AppColors.syncFailed;
      icon = Icons.error_outline_rounded;
      message = '${loc.translate('syncFailed')} ($pendingCount)';
      showSyncButton = true;
    } else {
      // Synced or Idle
      if (pendingCount > 0) {
        bgColor = AppColors.syncPending.withValues(alpha: 0.12);
        borderColor = AppColors.syncPending;
        textColor = AppColors.syncPending;
        icon = Icons.cloud_upload_outlined;
        message = '${loc.translate('pendingSync')}: $pendingCount';
        showSyncButton = true;
      } else {
        bgColor = AppColors.syncSuccess.withValues(alpha: 0.12);
        borderColor = AppColors.syncSuccess;
        textColor = AppColors.syncSuccess;
        icon = Icons.cloud_done_rounded;
        message = '${loc.translate('synced')} • ${loc.translate('onlineConnected')}';
        showSyncButton = false;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
          if (showSyncButton) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSyncPressed,
              style: TextButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 36),
                maximumSize: const Size(160, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(loc.translate('syncNow')),
            ),
          ],
        ],
      ),
    );
  }
}
