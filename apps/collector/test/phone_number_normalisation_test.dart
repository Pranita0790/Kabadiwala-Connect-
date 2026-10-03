import 'package:flutter_test/flutter_test.dart';
import 'package:kabadiwala_connect/services/firebase_auth_service.dart';

/// The Dart and Node normalisers must agree character for character.
///
/// `normaliseIndianPhone` in
/// services/backend/src/modules/auth/auth.schema.js keys every collector
/// account on the E.164 string. If the app normalises `09876543210` to
/// `+919876543210` but the backend normalises the same input to `+9809876543`
/// — or to something the DB treats as a different row — a collector signing in
/// twice ends up with two accounts, and their lots are split between them.
///
/// Every expectation below is mirrored by a case in
/// services/backend/tests/... for normalisePhone. If one side changes, this
/// test is the signal that the other must change too.
void main() {
  group('normaliseIndianPhone accepts real Indian mobile numbers', () {
    const accepted = {
      '9876543210': '+919876543210',
      '+919876543210': '+919876543210',
      '919876543210': '+919876543210',
      '09876543210': '+919876543210',
      '+91 98765 43210': '+919876543210',
      '98765 43210': '+919876543210',
      '98765-43210': '+919876543210',
      '+91-98765-43210': '+919876543210',
      '  9876543210  ': '+919876543210',
      '6123456789': '+916123456789', // starts with 6
      '7123456789': '+917123456789', // 7
      '8123456789': '+918123456789', // 8
      '9123456789': '+919123456789', // 9
    };

    accepted.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(normaliseIndianPhone(input), expected);
      });
    });
  });

  group('normaliseIndianPhone rejects everything else', () {
    const rejected = <String>[
      '',
      '   ',
      'abc',
      '12345',
      '98765', // too short
      '98765432101', // 11 digits, no leading 0
      '987654321012', // 12 digits, does not start 91
      '+14155552671', // US number
      '+972501234567', // Israel
      '+447911123456', // UK
      '+9876543210', // +91 but only 9 national digits
      '+91987654321001', // too long
      '+1 415 555 2671', // US, spaced
      '98765432101', // 11 digits starting 9
      '4155552671', // US national number without a country code
      '0987654321', // 10 digits starting 0
      '+0919876543210', // +09 is not a country code
      '0000000000',
      '1111111111', // Indian range starts at 6
    ];

    for (final input in rejected) {
      test('rejects "$input"', () {
        expect(normaliseIndianPhone(input), isNull);
      });
    }

    test('rejects a non-string input rather than throwing', () {
      // Guard against a null slipping in from a text controller.
      expect(() => normaliseIndianPhone(null as dynamic), throwsA(anything));
    });
  });

  group('idempotence', () {
    test('normalising an already-normalised number is a no-op', () {
      const once = '+919876543210';

      expect(normaliseIndianPhone(once), once);
      expect(normaliseIndianPhone(normaliseIndianPhone(once)!), once);
    });
  });
}