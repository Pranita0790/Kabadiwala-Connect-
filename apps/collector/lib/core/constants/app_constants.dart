class AppConstants {
  static const String appName = 'Kabadiwala Connect';

  /// Android emulator loopback to the host machine. Physical devices must pass
  /// `--dart-define=BACKEND_URL=http://YOUR_LAN_IP:5000`.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const String apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Uses [backendBaseUrl]/api unless `API_BASE_URL` is set explicitly.
  static String get apiBaseUrl =>
      apiBaseUrlOverride.isEmpty ? '$backendBaseUrl/api' : apiBaseUrlOverride;

  static const String appVersion = '1.0.0';

  static const String logoAsset = 'assets/images/kabadiwala_connect_logo.png';
  static const String dbName = 'kabadiwala_collector.db';
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

/// Demo collector used by Quick Demo Access. Login/register goes through the
/// Node gateway so the session has a real JWT (not SQLite-only).
class DemoAuth {
  /// While true, `AuthController.initialize()` signs [name] in automatically.
  static const bool autoSignInEnabled = false;

  static const String phoneNumber = '9876543210';
  static const String name = 'Ramesh Shinde';
  static const String city = 'Pune';
  static const String role = 'collector';

  /// Public demo password (min 8 chars for `/api/auth/register`). Not a prod secret.
  static const String password = 'Pass1234a';
}
