# Firebase Phone Authentication

How a collector signs in with a phone number, and where the trust boundaries
are.

Replaces the previous in-app SMS OTP. Collectors have **no password**.

---

## 1. Why Firebase owns the SMS

A real SMS gateway and OTP lifecycle are expensive to build and easy to get
wrong (delivery, retries, abuse, number recycling). Firebase Phone Auth is a
battle-tested front end for exactly this. The backend still owns the platform
session: Firebase proves a phone number was verified, nothing more.

The collector app never receives a platform credential from Firebase. It
receives a Firebase ID token, which it hands to the backend in exchange for a
platform access + refresh token.

---

## 2. Components and trust boundary

```text
┌────────────────────┐         ┌──────────────┐
│  Collector App      │  1 SMS  │   Firebase   │
│  (Flutter)          │ ───────▶│   Phone Auth │
│                     │◀────────│              │
│                     │ 2 code  │              │
│                     │ 3 ID    │              │
│                     │ token   │              │
└─────────┬───────────┘         └──────────────┘
          │ 4 ID token
          ▼
┌────────────────────┐  5 verify   ┌──────────────────────┐
│  Node.js Backend    │────────────▶│ Google public JWKS    │
│  (primary gateway)  │◀────────────│ (public certificates) │
│                     │             └──────────────────────┘
│  6 link/create user │
│  7 issue session    │
└─────────┬───────────┘
          │ 8 access + refresh
          ▼
    Collector App (offline-first, stores session in SQLite)
```

Trust rules:

- The backend trusts a phone number **only** from a Firebase ID token whose
  signature, `aud`, `iss`, and expiry all verify.
- The backend never trusts a client-supplied phone number, role, or user id.
- The SMS code never reaches the backend and is never logged.
- No Firebase admin SDK / service-account key is used anywhere, so there is no
  long-lived server credential to leak. The only server setting is the public
  **project id**.

---

## 3. Sequence

1. Collector enters a phone number. The app normalises it to E.164.
2. `FirebaseAuth.verifyPhoneNumber` asks Firebase to send the SMS.
3. Collector types the 6-digit code. `PhoneAuthProvider.credential` +
   `signInWithCredential` give the device a Firebase user.
4. `user.getIdToken()` → Firebase ID token.
5. `POST /api/auth/firebase/sign-in { idToken }`.
6. Backend verifies the token against Google JWKS
   (`services/backend/src/lib/firebase.js`) and resolves an account.
7. Backend issues its own access + refresh token and returns the public user.
8. App stores the session in SQLite (`SessionStore`) and routes to home, or to
   the profile form when `needsProfile` is true.

On later launches the app restores the cached session **without the network**
(see section 6).

---

## 4. Backend verification

`services/backend/src/lib/firebase.js`:

- Fetches Google's JWKS and verifies with `jose`.
- Pins `algorithms: ["RS256"]` — blocks `alg: none` and HMAC-with-public-key
  confusion.
- Checks `audience == FIREBASE_PROJECT_ID` and
  `issuer == https://securetoken.google.com/<id>`.
- `exp` / `nbf` with a 5-second clock tolerance; requires a non-empty `sub`.
- Maps every failure to a fixed, user-safe message; only the reason code is
  logged, never the token.
- JWKS is **injected**, not read from an env-configurable URL: a settable key
  source is an account-takeover footgun.

`services/backend/src/modules/auth/firebase-auth.service.js` resolves the
account:

1. by `firebase_uid` (authoritative for a returning device);
2. else by `phone` (links an existing account);
3. else creates a `COLLECTOR` with `is_verified = true` and no password.

Linking is guarded so concurrent sign-ins cannot attach one Firebase identity
to two rows; an already-linked number returns `PHONE_LINK_CONFLICT`.

---

## 5. Error codes → app message keys

Backend `code` (see `docs/api/api-contract.md`) are mapped to localisation keys
in `apps/collector/lib/services/collector_auth_service.dart`:

| Backend code                    | App key                         |
|---------------------------------|---------------------------------|
| `network` (client-side)         | `authErrorNetwork`              |
| `FIREBASE_NOT_CONFIGURED`       | `authErrorServerMisconfigured`  |
| `PHONE_NOT_SUPPORTED`           | `authErrorPhoneNotSupported`    |
| `FIREBASE_PROVIDER_NOT_ALLOWED` | `authErrorPhoneOnly`            |
| `ACCOUNT_INACTIVE`              | `authErrorAccountInactive`      |
| `FIREBASE_TOKEN_INVALID`        | `authErrorSessionExpired`       |
| `PHONE_LINK_CONFLICT`           | `authErrorLinkConflict`         |
| `RATE_LIMITED`                  | `authErrorTooManyAttempts`      |
| anything else                   | `authErrorUnknown`              |

Firebase SDK failures map to `authErrorSendFailed`, `authErrorInvalidCode`,
`authErrorCodeExpired`, `authErrorInvalidNumber`, and `authErrorNotConfigured`.
All keys exist for **en / hi / mr** in
`apps/collector/lib/core/localization/app_localizations.dart`.

---

## 6. Offline-first behaviour (AGENTS.md section 6)

Signing in needs a network; **working** does not.

- On cold start the app restores a cached session from SQLite and enters the
  app with no signal. Records are written locally and synced later.
- Only the OTP steps (request code / verify code) require connectivity.
- If Firebase is not configured — or the platform is unsupported (e.g. desktop
  dev) — the app still starts; `isPhoneAuthAvailable` is `false` and the UI
  explains why instead of crashing on first tap.

---

## 7. Configuration

### Backend — `services/backend/.env` (see `.env.example`)

```bash
FIREBASE_PROJECT_ID=your-project-id   # public; the only Firebase setting needed
```

Unset ⇒ `/api/auth/firebase/sign-in` returns `FIREBASE_NOT_CONFIGURED` (503)
and `/health/ready` reports `checks.phoneAuth: "disabled"` (non-fatal).

### Collector app — `apps/collector/.env` (see `.env.example`)

```bash
FIREBASE_API_KEY=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=          # must match the backend
FIREBASE_STORAGE_BUCKET=
FIREBASE_APP_ID_ANDROID=
FIREBASE_APP_ID_IOS=
```

Run with:

```bash
flutter run --dart-define-from-file=.env
```

`lib/firebase_options.dart` reads these via `String.fromEnvironment` and passes
them to `Firebase.initializeApp(options: ...)`. `flutterfire configure` is an
alternative; it overwrites `firebase_options.dart` with hardcoded values and
generates the platform config files.

---

## 8. Firebase Console setup checklist

1. Create a Firebase project (or reuse one).
2. **Authentication → Sign-in method → Phone → Enable.**
3. Add an **Android** app with package `com.kabadiwala.connect`; add the debug
   and release **SHA-1 / SHA-256** fingerprints, then download
   `google-services.json` (only needed if not using the `.env` path).
4. Add an **iOS** app with bundle id `com.kabadiwala.connect`; download
   `GoogleService-Info.plist`; enable **Push Notifications** and
   **Background Modes → Remote notifications** (silent APNs for automatic
   verification).
5. Copy the client values into `apps/collector/.env`; set
   `FIREBASE_PROJECT_ID` on the backend.
6. Phone Auth requires the **Blaze** plan once the free daily quota is passed.

---

## 9. Security properties

- No password for collectors means no password database to breach.
- Tokens are verified against Google's public keys; algorithm confusion and
  `alg: none` are rejected.
- The ID token is treated as a credential: never logged, never persisted beyond
  what the SDK needs.
- Platform tokens are the backend's own JWTs; Firebase cannot mint them.
- Secrets stay out of Git (AGENTS.md section 9). Only the public project id is
  configured server-side.

---

## 10. Tests

| File | Covers |
|------|--------|
| `tests/unit/firebase-token.test.js` | Real RSA tokens: `alg:none`, HS256 confusion, wrong `aud`/`iss`, expired/`nbf`, missing `sub`. |
| `tests/integration/firebase-auth.test.js` | Account create/link, provider rejection, conflicts, inactive accounts, config fault (503). |
| `tests/unit/phone-normalisation.test.js` | E.164 normalisation, Indian-mobile rules. |
| `apps/collector/test/phone_number_normalisation_test.dart` | Dart normaliser mirrored against the Node rules. |

Run backend: `TEST_DATABASE_URL="postgres://localhost/kabadiwala_migtest" npm test`
Run app: `flutter test`
