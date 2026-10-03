import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/models/handover.dart';

void main() {
  group('Handover.deriveHandoverPin', () {
    test('derives a stable 6-digit PIN from a UUID lot id', () {
      const lotId = 'fc6ba8ec-f3dc-4938-a26a-91734a2ead0d';
      final pin = Handover.deriveHandoverPin(lotId);
      expect(pin.length, 6);
      expect(int.tryParse(pin), isNotNull);
      // Same seed always yields the same PIN.
      expect(Handover.deriveHandoverPin(lotId), pin);
      // First 8 hex of UUID: fc6ba8ec
      expect(pin, (int.parse('fc6ba8ec', radix: 16) % 1000000).toString().padLeft(6, '0'));
    });

    test('handles non-hex local lot ids used in tests', () {
      final pin = Handover.deriveHandoverPin('lot_test_001');
      expect(pin.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(pin), isTrue);
    });

    test('payload JSON includes pin field', () {
      final payload = Handover.buildSafeQrPayload(
        handoverId: 'h1',
        lotId: 'fc6ba8ec-f3dc-4938-a26a-91734a2ead0d',
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      expect(map['pin'], Handover.deriveHandoverPin('fc6ba8ec-f3dc-4938-a26a-91734a2ead0d'));
      expect(map['type'], 'E_WASTE_HANDOVER');
    });
  });
}
