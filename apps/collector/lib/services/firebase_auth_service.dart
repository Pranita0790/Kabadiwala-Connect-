import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Why a phone sign-in attempt could not be completed.
///
/// Deliberately a closed set: the UI branches on these, so an unknown Firebase
/// error must not silently read as success or as a generic failure.
enum PhoneAuthFailure {
  /// The device could not reach Firebase. Offline, or no signal.
  network,

  /// The number as typed is not an Indian mobile number.
  invalidNumber,

  /// Firebase refused to send: quota, too many requests, or the number is
  /// blocked.
  sendFailed,

  /// The code the collector typed did not match.
  invalidCode,

  /// The code expired. Firebase SMS codes are short-lived.
  codeExpired,

  /// The session id went stale, e.g. the collector backgrounded the app.
  sessionExpired,

  /// Firebase or this build is not configured.
  notConfigured,

  /// Anything else.
  unknown,
}

class PhoneAuthException implements Exception {
  final PhoneAuthFailure reason;

  /// Firebase's own message, for the log only. Never shown to a collector.
  final String? debugDetail;

  const PhoneAuthException(this.reason, [this.debugDetail]);

  /// Message key for the localisation layer, not a literal user-facing string.
  String get messageKey => switch (reason) {
        PhoneAuthFailure.network => 'authErrorNetwork',
        PhoneAuthFailure.invalidNumber => 'authErrorInvalidNumber',
        PhoneAuthFailure.sendFailed => 'authErrorSendFailed',
        PhoneAuthFailure.invalidCode => 'authErrorInvalidCode',
        PhoneAuthFailure.codeExpired => 'authErrorCodeExpired',
        PhoneAuthFailure.sessionExpired => 'authErrorSessionExpired',
        PhoneAuthFailure.notConfigured => 'authErrorNotConfigured',
        PhoneAuthFailure.unknown => 'authErrorUnknown',
      };

  @override
  String toString() => 'PhoneAuthException($reason)';
}

/// The result of verifying an SMS code.
///
/// Carries the Firebase ID token, which the backend exchanges for its own
/// session. The Firebase token itself is never persisted here: the backend
/// session is the credential the app actually uses, and holding two tokens
/// doubles the blast radius of a device compromise for no benefit.
class PhoneAuthIdentity {
  final String idToken;
  final String? firebaseUid;

  const PhoneAuthIdentity({required this.idToken, this.firebaseUid});
}

/// Wraps Firebase Phone Auth.
///
/// Owns exactly one responsibility: proving to Firebase that the collector
/// controls the phone number, and returning the resulting ID token. It knows
/// nothing about the Kabadiwala backend, sessions, or roles — that boundary
/// is in `collector_auth_service.dart`.
///
/// Firebase sends and verifies the SMS. The backend never sees the code.
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _injectedAuth = auth;

  final FirebaseAuth? _injectedAuth;

  /// Resolved lazily.
  ///
  /// `FirebaseAuth.instance` throws if Firebase has not been initialised yet,
  /// so this cannot be a constructor-time field: the service is built before
  /// `ensureInitialised()` runs.
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  static bool _initialised = false;

  /// True when Firebase has been initialised successfully this run.
  static bool get isReady => _initialised;

  /// Initialise Firebase once per process.
  ///
  /// Returns false instead of throwing when config is missing so the app can
  /// still start and show an explanatory screen. Refusing to boot would leave
  /// a collector with no way to read the message.
  static Future<bool> ensureInitialised() async {
    if (_initialised) return true;

    try {
      await Firebase.initializeApp();
      _initialised = true;
      return true;
    } catch (error) {
      developer.log(
        'Firebase initialisation failed. Phone sign-in is unavailable. '
        'Run `flutterfire configure` to generate firebase_options.dart.',
        name: 'collector.firebase',
        error: error,
      );
      return false;
    }
  }

  /// Ask Firebase to text a code to [phone].
  ///
  /// Returns the `verificationId`, which is an opaque handle Firebase issues.
  /// It is not a credential and is worthless to anyone without the SMS code —
  /// but it is still not logged.
  ///
  /// Throws [PhoneAuthException] on failure. Returns normally on success, and
  /// [completer] fires when the SMS has actually been sent, so a slow
  /// network does not look like instant success.
  Future<String> requestCode(
    String phone, {
    Completer<void>? completer,
  }) async {
    if (!_initialised) {
      throw const PhoneAuthException(PhoneAuthFailure.notConfigured);
    }

    final normalised = normaliseIndianPhone(phone);

    if (normalised == null) {
      throw const PhoneAuthException(PhoneAuthFailure.invalidNumber);
    }

    // In firebase_auth 6.x verifyPhoneNumber returns void, so the
    // verificationId arrives on the codeSent callback. Resend support means
    // the id changes per send, so it is resolved by the most recent send.
    final pending = Completer<String>();

    void onCodeSent(String verificationId, int? forceResendingToken) {
      developer.log(
        'Firebase sent a code for a verified phone number',
        name: 'collector.firebase',
      );

      if (!pending.isCompleted) pending.complete(verificationId);
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        // Automatic SMS retrieval needs a registered Android app plus a
        // matching App Check attestation. Without it, or on iOS, the collector
        // types the code — which is the normal path.
        verificationCompleted: (PhoneAuthCredential credential) async {
          // The OS read the SMS itself, so manual entry can be skipped.
          completer?.complete();
        },
        verificationFailed: (FirebaseAuthException error) {
          developer.log(
            'Firebase declined to send a code',
            name: 'collector.firebase',
            error: error,
          );

          if (!pending.isCompleted) {
            pending.completeError(
              PhoneAuthException(PhoneAuthFailure.sendFailed, error.message),
            );
          }

          completer?.completeError(
            PhoneAuthException(PhoneAuthFailure.sendFailed, error.message),
          );
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (String verificationId) {
          // Nothing typed yet. Leave the flow open so manual entry can still
          // complete it.
        },
        timeout: const Duration(minutes: 5),
      );
    } on FirebaseAuthException catch (error) {
      developer.log(
        'Phone verification request failed',
        name: 'collector.firebase',
        error: error,
      );

      throw PhoneAuthException(_mapError(error.code), error.message);
    }

    try {
      return await pending.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw const PhoneAuthException(
          PhoneAuthFailure.network,
        ),
      );
    } on PhoneAuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw PhoneAuthException(_mapError(error.code), error.message);
    }
  }

  /// Verify [smsCode] against the Firebase session started by [requestCode].
  ///
  /// Returns the ID token for the backend to verify.
  Future<PhoneAuthIdentity> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!_initialised) {
      throw const PhoneAuthException(PhoneAuthFailure.notConfigured);
    }

    final code = smsCode.trim();

    if (code.isEmpty) {
      throw const PhoneAuthException(PhoneAuthFailure.invalidCode);
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      final credentialResult = await _auth.signInWithCredential(credential);
      final user = credentialResult.user;

      if (user == null) {
        throw const PhoneAuthException(PhoneAuthFailure.sessionExpired);
      }

      // Force a fresh token: a cached one may predate the phone sign-in, and
      // the backend rejects a stale aud/exp combination.
      final idToken = await user.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw const PhoneAuthException(PhoneAuthFailure.sessionExpired);
      }

      return PhoneAuthIdentity(idToken: idToken, firebaseUid: user.uid);
    } on FirebaseAuthException catch (error) {
      developer.log(
        'SMS code verification failed',
        name: 'collector.firebase',
        error: error,
      );

      throw PhoneAuthException(_mapError(error.code), error.message);
    } catch (error, stack) {
      developer.log(
        'Unexpected failure verifying a phone code',
        name: 'collector.firebase',
        error: error,
        stackTrace: stack,
      );

      throw const PhoneAuthException(PhoneAuthFailure.unknown);
    }
  }

  /// Forget the Firebase session. Local only; the backend session is
  /// revoked separately.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      developer.log(
        'Firebase sign-out failed',
        name: 'collector.firebase',
        error: error,
      );
    }
  }

  /// True when a Firebase session already exists on this device, which lets
  /// an offline collector back in without re-entering a code.
  bool get hasCachedFirebaseSession => _auth.currentUser != null;

  PhoneAuthFailure _mapError(String code) => switch (code) {
        'invalid-phone-number' => PhoneAuthFailure.invalidNumber,
        'invalid-verification-code' => PhoneAuthFailure.invalidCode,
        'session-expired' => PhoneAuthFailure.sessionExpired,
        'too-many-requests' => PhoneAuthFailure.sendFailed,
        'network-request-failed' => PhoneAuthFailure.network,
        'quota-exceeded' => PhoneAuthFailure.sendFailed,
        _ => PhoneAuthFailure.unknown,
      };
}

/// Normalise an Indian mobile number to E.164, or null if it is not one.
///
/// Mirrors `normalisePhone` in
/// services/backend/src/modules/auth/auth.schema.js. Both sides must agree:
/// the backend keys accounts on this exact string, so a mismatch would
/// silently create a duplicate account.
String? normaliseIndianPhone(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');

  if (digits.isEmpty) return null;

  if (trimmed.startsWith('+')) {
    if (digits.length == 12 && digits.startsWith('91')) {
      return RegExp(r'^91[6-9]\d{9}$').hasMatch(digits) ? '+$digits' : null;
    }
    return null;
  }

  if (digits.length == 10) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? '+91$digits' : null;
  }

  if (digits.length == 12 && digits.startsWith('91')) {
    return RegExp(r'^91[6-9]\d{9}$').hasMatch(digits) ? '+$digits' : null;
  }

  if (digits.length == 11 && digits.startsWith('0')) {
    final national = digits.substring(1);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(national) ? '+91$national' : null;
  }

  return null;
}