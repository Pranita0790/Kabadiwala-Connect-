package com.kabadiwala.connect

import io.flutter.embedding.android.FlutterActivity

/**
 * Firebase Phone Auth requires reCAPTCHA, which needs this activity to be
 * declared in AndroidManifest.xml. The package here must match the
 * `applicationId` in build.gradle.kts and the Firebase console entry.
 */
class MainActivity : FlutterActivity()
