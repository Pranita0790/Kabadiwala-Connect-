import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/models/app_notification.dart';

void main() {
  test('parses backend notification envelope used by GET /api/notifications', () {
    final item = AppNotification.fromMap({
      'id': '11111111-1111-4111-8111-111111111111',
      'type': 'HANDOVER_CONFIRMED',
      'title': {'en': 'Payment received', 'hi': 'भुगतान प्राप्त हुआ', 'mr': 'पेमेंट मिळाला'},
      'body': {'en': 'Recycler paid ₹500', 'hi': '₹500', 'mr': '₹500'},
      'lotId': 'lot-1',
      'isRead': false,
      'createdAt': '2026-10-03T18:30:00.000Z',
    });

    expect(item.id, '11111111-1111-4111-8111-111111111111');
    expect(item.type, 'HANDOVER_CONFIRMED');
    expect(item.titleEn, 'Payment received');
    expect(item.bodyEn, 'Recycler paid ₹500');
    expect(item.isDemo, isFalse);
    expect(item.relatedId, 'lot-1');
  });
}
