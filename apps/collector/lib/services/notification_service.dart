import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import '../models/price.dart';
import '../models/price_alert.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Service managing in-app notifications and material price alerts.
/// Fully decoupled from UI with offline SQLite persistence and live stream updates.
class NotificationService {
  static NotificationService? _instance;

  final DatabaseService _dbService;
  final ApiService _apiService;
  final Uuid _uuid;

  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  final StreamController<List<AppNotification>> _notificationsController =
      StreamController<List<AppNotification>>.broadcast();

  NotificationService({
    DatabaseService? dbService,
    ApiService? apiService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _apiService = apiService ?? RemoteApiService.instance,
        _uuid = const Uuid() {
    _instance = this;
  }

  static void setInstance(NotificationService? instance) {
    _instance = instance;
  }

  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  static NotificationService get instance =>
      _instance ?? NotificationService();

  Stream<int> get unreadCountStream => _unreadCountController.stream;
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;

  Future<List<AppNotification>> getNotifications() async {
    return _dbService.getNotifications();
  }

  Future<int> getUnreadCount() async {
    return _dbService.getUnreadNotificationCount();
  }

  Future<void> refreshNotifications() async {
    try {
      final list = await _dbService.getNotifications();
      final count = await _dbService.getUnreadNotificationCount();
      if (!_notificationsController.isClosed) {
        _notificationsController.add(list);
      }
      if (!_unreadCountController.isClosed) {
        _unreadCountController.add(count);
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    await _dbService.markNotificationAsRead(id);
    await refreshNotifications();
  }

  Future<void> markAllAsRead() async {
    await _dbService.markAllNotificationsAsRead();
    await refreshNotifications();
  }

  Future<void> clearAll() async {
    await _dbService.clearAllNotifications();
    await refreshNotifications();
  }

  // ==========================================
  // PRICE ALERTS
  // ==========================================

  Future<PriceAlert> createPriceAlert({
    String? id,
    String? categoryId,
    String? categoryName,
    String? material,
    required double targetPrice,
    String unit = 'kg',
  }) async {
    final alertId = id ?? _uuid.v4();
    final catId = categoryId ?? material?.toLowerCase().replaceAll(' ', '_') ?? 'material';
    final catName = categoryName ?? material ?? 'E-Waste';
    final now = DateTime.now();

    final alert = PriceAlert(
      id: alertId,
      categoryId: catId,
      categoryName: catName,
      targetPrice: targetPrice,
      unit: unit,
      createdAt: now,
      isActive: true,
    );

    // 1. Save the price alert into SQLite
    await _dbService.insertPriceAlert(alert);

    // 2. Create corresponding notification record in SQLite
    // Using idempotent ID linked to alert ID to avoid duplicate creation
    final notifId = 'notif_alert_$alertId';
    final notif = AppNotification(
      id: notifId,
      titleEn: '🔔 Price Alert: $catName',
      titleHi: '🔔 भाव इशारा: $catName',
      titleMr: '🔔 दर इशारा: $catName',
      bodyEn: '$catName price alert created at ₹${targetPrice.toStringAsFixed(0)}/$unit. You will be notified when market rates meet your target.',
      bodyHi: '$catName के लिए ₹${targetPrice.toStringAsFixed(0)}/$unit पर भाव अलर्ट सेट किया गया।',
      bodyMr: '$catName साठी ₹${targetPrice.toStringAsFixed(0)}/$unit वर दर अलर्ट सेट केला गेला.',
      type: AppConstants.notificationPriceAlert,
      relatedId: alertId,
      timestamp: now,
      isRead: false,
      isDemo: true,
    );

    await _dbService.insertNotification(notif);

    // 3. Inform remote backend if online
    try {
      await _apiService.uploadPriceAlert(alert);
    } catch (_) {}

    // 4. Refresh notification streams reactively
    await refreshNotifications();

    return alert;
  }

  Future<void> triggerPriceAlertDemo({
    required String material,
    required double targetPrice,
    required double currentPrice,
  }) async {
    await simulateDemoPriceAlert(
      categoryName: material,
      price: currentPrice,
    );
  }

  Future<List<PriceAlert>> getPriceAlerts() => _dbService.getPriceAlerts();

  Future<List<PriceAlert>> getActivePriceAlerts() => _dbService.getActivePriceAlerts();

  Future<void> deletePriceAlert(String id) => _dbService.deletePriceAlert(id);

  /// Checks active price alerts against current market prices and fires notifications
  Future<int> checkPriceAlertsAgainstPrices(List<Price> currentPrices) async {
    final activeAlerts = await _dbService.getActivePriceAlerts();
    if (activeAlerts.isEmpty || currentPrices.isEmpty) return 0;

    int triggeredCount = 0;
    final now = DateTime.now();

    for (final alert in activeAlerts) {
      final matchingPrice = currentPrices.firstWhere(
        (p) =>
            p.id == alert.categoryId ||
            p.material.toLowerCase() == alert.categoryId.toLowerCase() ||
            p.categoryNameEn.toLowerCase() == alert.categoryName.toLowerCase(),
        orElse: () => Price(
          id: '',
          material: '',
          minPrice: 0,
          maxPrice: 0,
          unit: 'kg',
          location: '',
          source: '',
          updatedAt: now,
        ),
      );

      if (matchingPrice.id.isNotEmpty && matchingPrice.maxPrice >= alert.targetPrice) {
        // Price alert triggered!
        final notif = AppNotification(
          id: _uuid.v4(),
          titleEn: '🔔 Price Alert: ${alert.categoryName}',
          titleHi: '🔔 भाव इशारा: ${alert.categoryName}',
          titleMr: '🔔 दर इशारा: ${alert.categoryName}',
          bodyEn: '${alert.categoryName} market price reached ₹${matchingPrice.maxPrice.toStringAsFixed(0)}/${alert.unit}, matching your alert target of ₹${alert.targetPrice.toStringAsFixed(0)}.',
          bodyHi: '${alert.categoryName} का बाजार भाव ₹${matchingPrice.maxPrice.toStringAsFixed(0)}/${alert.unit} पहुंच गया है।',
          bodyMr: '${alert.categoryName} चा बाजार दर ₹${matchingPrice.maxPrice.toStringAsFixed(0)}/${alert.unit} पोहोचला आहे.',
          type: AppConstants.notificationPriceAlert,
          relatedId: alert.id,
          timestamp: now,
          isRead: false,
          isDemo: true,
        );

        await _dbService.insertNotification(notif);
        await _dbService.updatePriceAlertTriggered(alert.id, now);
        triggeredCount++;
      }
    }

    if (triggeredCount > 0) {
      await refreshNotifications();
    }

    return triggeredCount;
  }

  // ==========================================
  // DEMO / SIMULATION HELPERS
  // ==========================================

  Future<void> simulateDemoHandoverConfirmed({
    required String recyclerName,
    required String materialCategory,
    required double weightKg,
    required double amount,
  }) async {
    final notif = AppNotification(
      id: _uuid.v4(),
      titleEn: '✓ [DEMO] Handover Confirmed',
      titleHi: '✓ [डेमो] माल हस्तांतरण निश्चित झाले',
      titleMr: '✓ [डेमो] माल हस्तांतरण निश्चित झाले',
      bodyEn: '$materialCategory ($weightKg kg) handed over to $recyclerName. ₹${amount.toStringAsFixed(0)} credited.',
      bodyHi: '$materialCategory ($weightKg किलो) $recyclerName को सौंपा गया। ₹${amount.toStringAsFixed(0)} प्राप्त।',
      bodyMr: '$materialCategory ($weightKg किलो) $recyclerName ला दिले. ₹${amount.toStringAsFixed(0)} जमा.',
      type: AppConstants.notificationHandover,
      timestamp: DateTime.now(),
      isRead: false,
      isDemo: true,
    );
    await _dbService.insertNotification(notif);
    await refreshNotifications();
  }

  Future<void> simulateDemoPriceAlert({
    required String categoryName,
    required double price,
  }) async {
    final notif = AppNotification(
      id: _uuid.v4(),
      titleEn: '🔔 [DEMO] Price Alert: $categoryName',
      titleHi: '🔔 [डेमो] भाव इशारा: $categoryName',
      titleMr: '🔔 [डेमो] दर इशारा: $categoryName',
      bodyEn: '$categoryName price reached ₹${price.toStringAsFixed(0)}/kg matching your alert target.',
      bodyHi: '$categoryName का भाव ₹${price.toStringAsFixed(0)}/किलो पहुंच गया है।',
      bodyMr: '$categoryName चा दर ₹${price.toStringAsFixed(0)}/किलो पोहोचला आहे.',
      type: AppConstants.notificationPriceAlert,
      timestamp: DateTime.now(),
      isRead: false,
      isDemo: true,
    );
    await _dbService.insertNotification(notif);
    await refreshNotifications();
  }

  void dispose() {
    _unreadCountController.close();
    _notificationsController.close();
  }
}
