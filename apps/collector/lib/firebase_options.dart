// ============================================================================
// FIREBASE CLIENT CONFIGURATION
//
// Two supported ways to fill this in, pick one.
//
// 1. ENV FILE (used for local dev and CI — no secrets committed)
//
//    Create apps/collector/.env (git-ignored) from .env.example, then run:
//
//      flutter run --dart-define-from-file=.env
//
//    The values below are read with String.fromEnvironment, so they must be
//    passed as --dart-define / --dart-define-from-file at build time.
//
// 2. FLUTTERFIRE CLI
//
//      dart pub global activate flutterfire_cli
//      flutterfire configure --project=<id> --platforms=android,ios
//
//    This overwrites this file with hardcoded values and generates
//    android/app/google-services.json + ios/Runner/GoogleService-Info.plist.
//    If you use this path, ignore the env file.
//
// WHY THROWING IS BETTER THAN PLACEHOLDER VALUES
//
// A fabricated apiKey/appId looks like it works and then fails deep inside the
// SDK with a network or permission error, hours later. Throwing here points
// straight at the missing step.
//
// Nothing here is a secret: Firebase client config is public by design
// (Google documents it as such), and the backend verifies ID tokens using
// Google's public certificates, not this data. It is kept out of Git only to
// avoid environment mixups between team members.
//
// The matching backend setting is FIREBASE_PROJECT_ID — see
// services/backend/.env.example.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String _appIdAndroid =
      String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const String _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');

  static const String _notConfigured =
      'Firebase is not configured.\n\n'
      'Set the FIREBASE_* values in apps/collector/.env and build with:\n'
      '  flutter run --dart-define-from-file=.env\n\n'
      'or run `flutterfire configure`. Also set FIREBASE_PROJECT_ID on the '
      'backend so it can verify ID tokens.';

  /// True when every value the mobile platforms need is present.
  ///
  /// The auth flow calls this before touching the SDK so an unconfigured build
  /// shows a clear message instead of crashing on the first sign-in tap.
  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty &&
      (_appIdAndroid.isNotEmpty || _appIdIos.isNotEmpty);

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw UnsupportedError(_notConfigured);
    }

    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not a supported collector platform. Use Android or iOS.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase phone sign-in is only wired for Android and iOS, not '
          '${defaultTargetPlatform.name}. The rest of the app still runs '
          'offline with a cached session.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _apiKey,
        appId: _require(_appIdAndroid, 'FIREBASE_APP_ID_ANDROID'),
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _apiKey,
        appId: _require(_appIdIos, 'FIREBASE_APP_ID_IOS'),
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        iosBundleId: 'com.kabadiwala.connect',
      );

  static String _require(String value, String name) {
    if (value.isEmpty) {
      throw UnsupportedError(
        'Firebase is missing $name. Add it to apps/collector/.env and build '
        'with --dart-define-from-file=.env.',
      );
    }
    return value;
  }
}
