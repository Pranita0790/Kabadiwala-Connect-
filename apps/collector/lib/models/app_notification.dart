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
    final title = map['title'];
    final body = map['body'];
    String pick(dynamic nested, String lang, List<String> keys, String fallback) {
      if (nested is Map && nested[lang] != null) {
        return nested[lang].toString();
      }
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    final timestampRaw =
        map['timestamp'] ?? map['createdAt'] ?? map['created_at'];
    DateTime timestamp = DateTime.now();
    if (timestampRaw is String) {
      timestamp = DateTime.tryParse(timestampRaw) ?? timestamp;
    } else if (timestampRaw is DateTime) {
      timestamp = timestampRaw;
    }

    final type = (map['type'] as String?) ?? AppConstants.notificationHandover;

    return AppNotification(
      id: (map['id'] ?? map['public_id'] ?? '').toString(),
      titleEn: pick(title, 'en', ['titleEn', 'title_en'], 'Notification'),
      titleHi: pick(title, 'hi', ['titleHi', 'title_hi'], 'सूचना'),
      titleMr: pick(title, 'mr', ['titleMr', 'title_mr'], 'सूचना'),
      bodyEn: pick(body, 'en', ['bodyEn', 'body_en'], ''),
      bodyHi: pick(body, 'hi', ['bodyHi', 'body_hi'], ''),
      bodyMr: pick(body, 'mr', ['bodyMr', 'body_mr'], ''),
      type: type,
      relatedId: (map['related_id'] ?? map['relatedId'] ?? map['lotId'])
          ?.toString(),
      timestamp: timestamp,
      isRead: (map['is_read'] == 1 ||
          map['is_read'] == true ||
          map['isRead'] == true),
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
