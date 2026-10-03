# Kabadiwala Connect — API Contract

The backend is the primary gateway (AGENTS.md section 2). The collector app and
the recycler dashboard talk only to this API; neither talks to the AI service or
Firebase directly for anything it should not.

Base URL (production): `https://kabadiwala-backend-69wr.onrender.com/api`

This document is the shared contract. Changing a path, field, status value, or
authentication requirement here requires updating this file first and coordinating
with the other clients (AGENTS.md section 5).

---

## 1. Response envelope

Every response is shaped by `services/backend/src/lib/response.js`.

### Success

```json
{
  "success": true,
  "message": "Signed in",
  "data": { }
}
```

`message` is omitted when not provided. Some legacy endpoints additionally emit a
top-level resource key for backward compatibility (see section 6).

### Error

```json
{
  "success": false,
  "code": "VALIDATION_ERROR",
  "message": "Human readable summary",
  "error": "Human readable summary",
  "details": { }
}
```

`error` is an alias of `message`. `details` is present only when the error
supplies it. Clients should branch on `code`, not on `message`.

---

## 2. Authentication model

The platform issues its **own** access token (JWT) and refresh token. Firebase
is only used to prove a phone number; it does not replace the platform session.

- **Access token** — short lived JWT (`JWT_ACCESS_TTL`, default 15m). Sent as
  `Authorization: Bearer <token>`.
- **Refresh token** — opaque, stored hashed server-side, rotated on every
  refresh (`JWT_REFRESH_TTL`, default 30d).
- **Roles** — `COLLECTOR`, `RECYCLER`, `ADMIN`. Authorization is enforced on the
  backend; the client never chooses its own role.

### Collector sign-in (Firebase Phone Auth)

Collectors have **no password**. Sign-in is a three-step flow:

1. The device asks Firebase to send an SMS to the phone number.
2. The device gives the 6-digit code to Firebase; Firebase validates it.
3. The device receives a Firebase **ID token**, and posts it to
   `/api/auth/firebase/sign-in`.

The backend verifies the ID token against **Google's public certificates**
(JWKS) and then creates or links a platform account. No Firebase admin SDK,
service-account key, or shared secret is used, and the SMS code never reaches
the backend.

```
Collector App ──(phone)──▶ Firebase
             ◀──(ID token)─
             ──(ID token)──▶ Backend ──(Google JWKS)──▶ verify
                                │
                                ├─ link/create users row (firebase_uid)
                                └─ issue access + refresh token
             ◀──(session)────
```

### `POST /api/auth/firebase/sign-in` — public

Exchange a verified Firebase phone ID token for a platform session.

**Request**

| Field      | Type   | Required | Notes                                                |
|------------|--------|----------|------------------------------------------------------|
| `idToken`  | string | yes      | Firebase ID token, 20–8192 chars. Never logged.      |
| `fullName` | string | no       | Collector's name, used when creating a new account.  |

**Resolution order (server-side)**

1. Match `users.firebase_uid` — authoritative for a returning device.
2. Otherwise match `users.phone` — links an existing (password or recycled)
   account to this Firebase identity.
3. Otherwise create a new `COLLECTOR` account with `is_verified = true` and no
   password hash.

**Responses**

- `200 OK` — existing account signed in.
- `201 Created` — new account created.

```json
{
  "success": true,
  "message": "Signed in",
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "opaque-token",
    "expiresInSeconds": 900,
    "user": {
      "id": "public-uuid",
      "fullName": "Ramesh",
      "phone": "+919876543210",
      "email": null,
      "role": "COLLECTOR",
      "isVerified": true,
      "isActive": true,
      "recyclerId": null,
      "organisationName": null,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "lastLoginAt": "2026-01-01T00:00:00.000Z"
    },
    "needsProfile": true
  }
}
```

`needsProfile` is `true` for a brand new account; the app routes to the profile
form without a second request.

**Error codes**

| Code                          | HTTP | Meaning                                          |
|-------------------------------|------|--------------------------------------------------|
| `VALIDATION_ERROR`            | 400  | Missing/oversized `idToken`, bad body.           |
| `INVALID_FIREBASE_TOKEN`      | 401  | Signature/`aud`/`iss`/`exp` failed.              |
| `FIREBASE_PROVIDER_NOT_ALLOWED`| 401 | Token was not from a `phone` provider.           |
| `PHONE_MISSING_FROM_TOKEN`    | 401  | Verified token carried no phone claim.           |
| `PHONE_NOT_SUPPORTED`         | 400  | Claim is not a valid Indian mobile number.       |
| `PHONE_LINK_CONFLICT`         | 409  | Number is already linked to a different identity.|
| `ACCOUNT_INACTIVE`            | 403  | Account deactivated.                             |
| `FIREBASE_NOT_CONFIGURED`     | 503  | `FIREBASE_PROJECT_ID` is unset on the server.    |
| `TOO_MANY_REQUESTS`           | 429  | Rate limited (`authLimiter`).                    |

All error text is fixed and user-safe; internal verification reasons are logged
server-side only.

### `POST /api/auth/login` — public

Password login for accounts that have a password (e.g. recycler dashboard).

- A collector account has no `password_hash`. Requesting password login for one
  returns an error with code `FIREBASE_SIGN_IN_REQUIRED` so the client knows to
  use the Firebase flow.

### `POST /api/auth/refresh` — public

Rotates the refresh token and returns a new access token. The previous refresh
token is revoked and linked to its replacement (`replaced_by_id`).

### `POST /api/auth/logout` — authenticated

Revokes the presented refresh token. Works even when the access token has
already expired so a client can always clear its session.

### `GET /api/auth/me` — authenticated

Returns the current user (`toPublicUser` shape, see above, minus tokens).

### `PATCH /api/auth/me` — authenticated

Updates the profile (name, city, and other allowed fields). Role and identity
are not client-editable.

### `GET /api/auth/roles` — public

Reference data for roles.

---

## 3. Email OTP

The OTP endpoints remain for **email** verification:

- `POST /api/auth/otp/request` — email only. Requests with `channel: "SMS"` or a
  non-email identifier are rejected with `VALIDATION_ERROR`; SMS delivery is
  owned by Firebase.
- `POST /api/auth/otp/verify` — consumes a single-use email challenge.

---

## 4. Health

- `GET /health/ready` — readiness probe. Reports dependencies.
- `GET /health/live` — liveness probe.

`checks.phoneAuth` reports `up` when `FIREBASE_PROJECT_ID` is set and `disabled`
otherwise. It is deliberately **not** part of `ready`: a deployment must serve
the dashboard even before Firebase is configured.

---

## 5. Data ownership

- `POST /api/auth/firebase/sign-in` is the only auth path a collector uses.
- The recycler dashboard uses password login plus the shared session endpoints.
- The AI service is reached only through the backend (`POST /api/ai/analyze`);
  the collector app never calls it directly (AGENTS.md section 7).

---

## 6. Legacy response shapes — must not change

Two shapes are depended on by the deployed dashboard:

- `GET /api/rates` → `{ success, rates: [...] }` (dashboard reads `data.rates`).
- `PUT /api/rates/:id` → a **bare** rate object (dashboard splices the whole
  response into state).

Do not "clean these up" without a contract change and a coordinated dashboard
release.
