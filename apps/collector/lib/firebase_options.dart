// ============================================================================
// GENERATED FILE — DO NOT EDIT BY HAND
//
// This is the file `flutterfire configure` writes. It has not been generated
// yet, because generation needs the Firebase project ID and a Firebase login.
//
// TO GENERATE (from the repository root, with the FlutterFire CLI installed):
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure \
//     --project=<your-firebase-project-id> \
//     --platforms=android,ios
//
// That overwrites this file with the real values.
//
// WHY THROWING IS BETTER THAN PLACEHOLDER VALUES
//
// A fabricated apiKey/appId looks like it works and then fails deep inside the
// SDK with a network or permission error, hours later. Throwing here points
// straight at the missing step. Nothing in this file is a secret: Firebase
// client config is public by design, and token verification on the backend
// uses Google's public certificates, not this data.
//
// The matching backend setting is FIREBASE_PROJECT_ID — see
// services/backend/.env.example.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String _notConfigured =
      'Firebase is not configured.\n\n'
      'Run `flutterfire configure` to generate lib/firebase_options.dart, and '
      'set FIREBASE_PROJECT_ID on the backend so it can verify ID tokens.';

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(_notConfigured);
  }
}