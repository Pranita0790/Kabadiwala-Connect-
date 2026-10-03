import '../core/constants/app_constants.dart';

/// Model for in-app collector notifications (e.g. Handover Confirmed, Price Alerts).
/// Fully localized and stored in local SQLite database for offline access.
class AppNotification {
  final String id;
  final String titleEn;
  final String titleHi;
  final String titleMr;
  final String bodyEn;
  final String bodyHi;
  final String bodyMr;
  final String type;
  final String? relatedId;
  final DateTime timestamp;
  final bool isRead;
  final bool isDemo;

  const AppNotification({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.titleMr,
    required this.bodyEn,
    required this.bodyHi,
    required this.bodyMr,
    this.type = AppConstants.notificationHandover,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
    this.isDemo = true,
  });

  String getLocalizedTitle(String langCode) {
    if (langCode == 'hi') return titleHi;
    if (langCode == 'mr') return titleMr;
    return titleEn;
  }

  String getLocalizedBody(String langCode) {
    if (langCode == 'hi') return bodyHi;
    if (langCode == 'mr') return bodyMr;
    return bodyEn;
  }

  String getTitle(String langCode) => getLocalizedTitle(langCode);
  String getBody(String langCode) => getLocalizedBody(langCode);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title_en': titleEn,
      'title_hi': titleHi,
      'title_mr': titleMr,
      'body_en': bodyEn,
      'body_hi': bodyHi,
      'body_mr': bodyMr,
      'type': type,
      'related_id': relatedId,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'is_demo': isDemo ? 1 : 0,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      titleEn: map['title_en'] as String? ?? 'Notification',
      titleHi: map['title_hi'] as String? ?? 'सूचना',
      titleMr: map['title_mr'] as String? ?? 'सूचना',
      bodyEn: map['body_en'] as String? ?? '',
      bodyHi: map['body_hi'] as String? ?? '',
      bodyMr: map['body_mr'] as String? ?? '',
      type: map['type'] as String? ?? AppConstants.notificationHandover,
      relatedId: map['related_id'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: (map['is_read'] == 1 || map['is_read'] == true),
      isDemo: (map['is_demo'] == 1 || map['is_demo'] == true),
    );
  }

  AppNotification copyWith({
    String? id,
    String? titleEn,
    String? titleHi,
    String? titleMr,
    String? bodyEn,
    String? bodyHi,
    String? bodyMr,
    String? type,
    String? relatedId,
    DateTime? timestamp,
    bool? isRead,
    bool? isDemo,
  }) {
    return AppNotification(
      id: id ?? this.id,
      titleEn: titleEn ?? this.titleEn,
      titleHi: titleHi ?? this.titleHi,
      titleMr: titleMr ?? this.titleMr,
      bodyEn: bodyEn ?? this.bodyEn,
      bodyHi: bodyHi ?? this.bodyHi,
      bodyMr: bodyMr ?? this.bodyMr,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
