class AppConstants {

  static const String appName = 'Kabadiwala Connect';

  static const String apiBaseUrl =
      'https://kabadiwala-backend-69wr.onrender.com/api';

  static const String appVersion = '1.0.0';

  static const String logoAsset = 'assets/images/kabadiwala_connect_logo.png';
  static const String dbName = 'kabadiwala_user.db';
  static const int dbVersion = 2;

  static const String tableLots = 'lots';
  static const String tableEWasteLots = 'lots';
  static const String tablePrices = 'prices';
  static const String tableTransactions = 'transactions';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableSettings = 'settings';
  static const String tableRecyclers = 'recyclers';
  static const String tableHandovers = 'handovers';
  static const String tableNotifications = 'notifications';
  static const String tablePriceAlerts = 'price_alerts';
  static const String tableUsers = 'users';

  // Sync States
  static const String syncPending = 'PENDING_SYNC';
  static const String syncSyncing = 'SYNCING';
  static const String syncSynced = 'SYNCED';
  static const String syncFailed = 'FAILED';

  // Handover States
  static const String handoverPending = 'PENDING_CONFIRMATION';
  static const String handoverConfirmed = 'CONFIRMED';
  static const String handoverCancelled = 'CANCELLED';

  // Notification Types
  static const String notificationHandover = 'HANDOVER_CONFIRMED';
  static const String notificationPriceAlert = 'PRICE_ALERT';
  static const String notificationSystem = 'SYSTEM';
  static const String notificationTypeHandover = 'HANDOVER_CONFIRMED';
  static const String notificationTypePriceAlert = 'PRICE_ALERT';
}

class HandoverStatus {
  static const String pending = 'PENDING_CONFIRMATION';
  static const String confirmed = 'CONFIRMED';
  static const String cancelled = 'CANCELLED';
}

