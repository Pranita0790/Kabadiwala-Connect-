class AppConstants {
  static const String appName = 'Kabadiwala Connect';

  /// Override at build/run time if your Wi-Fi IP changes:
  /// `--dart-define=BACKEND_URL=http://YOUR_IP:5001`
  /// `--dart-define=API_BASE_URL=http://YOUR_IP:5001/api`
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5001',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5001/api',
  );

  static const String mapTilerApiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: 'FD3r2uqNKjpGbL5UHaFm',
  );

  static const String mapTilerTileUrl =
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerApiKey';

  static String mapTilerStaticMapUrl({
    double lat = 18.5204,
    double lng = 73.8567,
    int zoom = 12,
    int width = 800,
    int height = 800,
  }) {
    return 'https://api.maptiler.com/maps/streets-v2/static/$lng,$lat,$zoom/${width}x$height.png?key=$mapTilerApiKey';
  }

  static const String appVersion = '1.0.0';

  static const String logoAsset = 'assets/images/kabadiwala_connect_logo.png';
  static const String dbName = 'kabadiwala_collector.db';
  static const int dbVersion = 3;

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
  static const String tableCollectorRates = 'collector_rates';
  static const String tablePickupRequests = 'pickup_requests';
  static const String tableCustomers = 'customers';

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

/// TEMPORARY: a ready-made collector so the app opens without signing in.
///
/// This exists so the build can be reviewed and demoed without an SMS round
/// trip. It grants nothing on the server — the profile is planted in local
/// SQLite only, so API calls still fail until a real session exists.
///
/// Setting [autoSignInEnabled] to false restores the normal login gate; no
/// other code has to change. Delete this class once real auth is in place.
class DemoAuth {
  /// While true, `AuthController.initialize()` signs [name] in automatically.
  static const bool autoSignInEnabled = false;

  static const String phoneNumber = '9876543210';
  static const String name = 'Ramesh Shinde';
  static const String city = 'Pune';
  static const String role = 'collector';

  /// No password is defined on purpose: the seeded profile has no backend
  /// account, so a password here would be a dead credential that reads like a
  /// real secret. The sign-in screen takes the password from the person using
  /// it.
}
