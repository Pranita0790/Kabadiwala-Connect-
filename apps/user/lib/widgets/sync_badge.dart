import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/app_localizations.dart';

/// Accessible, color-coded badge indicating the sync state of a record.
///
/// States:
/// - PENDING_SYNC: Waiting for internet / Pending
/// - SYNCING: Sync in progress
/// - SYNCED: Successfully uploaded to backend
/// - FAILED: Sync failed, queued for retry
class SyncBadge extends StatelessWidget {
  final String syncStatus;

  const SyncBadge({super.key, required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Color bg;
    IconData icon;
    String text;

    switch (syncStatus) {
      case AppConstants.syncPending:
        bg = AppColors.syncPending;
        icon = Icons.cloud_queue_rounded;
        text = loc.translate('pendingSync');
        break;
      case AppConstants.syncSyncing:
        bg = AppColors.syncing;
        icon = Icons.sync_rounded;
        text = loc.translate('syncing');
        break;
      case AppConstants.syncSynced:
        bg = AppColors.syncSuccess;
        icon = Icons.check_circle_rounded;
        text = loc.translate('synced');
        break;
      case AppConstants.syncFailed:
      default:
        bg = AppColors.syncFailed;
        icon = Icons.warning_amber_rounded;
        text = loc.translate('syncFailed');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
