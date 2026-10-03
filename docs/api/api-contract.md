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

### Collector sign-in

A collector created through the phone flow has **no password**. Sign-in for that
account is a three-step flow:

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

The collector app's **sign-in screen asks for a mobile number and a password**
and posts them to `/api/auth/login`; it no longer offers an SMS-code step. That
only works for an account that has a password — one created by
`POST /api/auth/register`, or whose password was set through
`POST /api/auth/change-password`. An account that has only ever used the phone
flow is refused with `FIREBASE_SIGN_IN_REQUIRED`. Sign-up on the device still
uses the Firebase flow above, so a new collector has no password to forget.

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

---

## 7. Rates and prices

Rates are the price board shared by every client.

| Method | Path                  | Auth            | Notes                                      |
|--------|-----------------------|-----------------|--------------------------------------------|
| `GET`  | `/api/rates`          | optional        | `{ success, rates[], count }` + `data`.    |
| `GET`  | `/api/rates/:id`      | optional        | Single rate, `{ success, data }`.          |
| `GET`  | `/api/rates/:id/history` | optional     | `{ success, data: { history[], count } }`. |
| `PUT`  | `/api/rates/:id`      | optional (public, see below) | Body `{ ratePerKg }`. **Bare** rate body. |

`/api/prices` is an alias of `/api/rates` (the collector app calls it "prices").

> **`PUT /api/rates/:id` is public today, on purpose.** The deployed Recycler
> Dashboard edits the board without an `Authorization` header; requiring a token
> would 401 the live board (AGENTS.md section 5). When the dashboard ships login,
> this endpoint moves to `requireRole(RECYCLER, ADMIN)`. A token is still
> accepted when present, so changes are attributed in the audit trail.

---

## 8. Lots

All lot endpoints require a bearer token (`requireAuth`).

| Method  | Path                      | Role            | Notes                                        |
|---------|---------------------------|-----------------|----------------------------------------------|
| `POST`  | `/api/lots/sync`          | COLLECTOR, ADMIN| Batch offline sync; idempotent per `clientId`.|
| `POST`  | `/api/lots`               | COLLECTOR, ADMIN| Create. `201` when newly created.            |
| `GET`   | `/api/lots`               | any authenticated | `{ success, lots[], count, meta }` + `data`.|
| `GET`   | `/api/lots/:id`           | any authenticated | `{ success, lot }` + `data`.                |
| `PATCH` | `/api/lots/:id`           | COLLECTOR, ADMIN| Optimistic concurrency via `version`.        |
| `PATCH` | `/api/lots/:id/status`    | RECYCLER, ADMIN (collector may withdraw to Rejected) | Canonical status transition; Accept claims the lot. |
| `DELETE`| `/api/lots/:id`           | COLLECTOR, ADMIN| Soft delete.                                 |
| `GET`   | `/api/lots/:id/analyses`  | any authenticated | AI analyses attached to the lot.            |
| `POST`  | `/api/lots/:id/analysis`  | COLLECTOR, ADMIN| Attach an AI analysis result.               |

Lot payloads are camelCase and also carry the collector's snake_case aliases
(`lot_id`, `material_type`, …) for backward compatibility.

---

## 9. Traceability

| Method | Path                        | Auth   | Notes                                       |
|--------|-----------------------------|--------|---------------------------------------------|
| `GET`  | `/api/traceability`         | public | `{ success, count, records[] }` + `data`.   |
| `GET`  | `/api/traceability/:lotId`  | public | `{ success, record }` + `data`.             |

Records expose `id`, `material`, `collector`, `weight`, `status` (Title-Cased
label), and `createdAt`.

> **These reads are public today, on purpose.** The deployed Traceability page
> fetches anonymously and falls back to `localStorage` on failure.
> **Privacy trade-off:** records include the collector's full name and collection
> address. Once the dashboard authenticates, this router must move behind
> `requireRole(RECYCLER, ADMIN)`.

---

## 10. Recyclers, handovers, and transactions

These endpoints connect the collector app and the recycler dashboard through
the shared Postgres tables (`recycler_profiles`, `handovers`, `transactions`).

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `GET` | `/api/recyclers` | optional | `{ success, recyclers[], count }` + `data`. Filter with `?categoryId=`. |
| `POST` | `/api/handovers` | COLLECTOR, RECYCLER, ADMIN | Create handover for a lot. Body accepts camelCase or collector snake_case (`lot_id`, `agreed_amount`, …). Idempotent on `clientReference` / UUID `id`. |
| `POST` | `/api/handovers/:id/confirm` | COLLECTOR, RECYCLER, ADMIN | Dual confirmation. When both sides (or an admin) confirm, creates a `transactions` row and moves the lot toward `COMPLETED`. |
| `GET` | `/api/transactions/my` | COLLECTOR, RECYCLER, ADMIN | Collector earnings ledger / recycler settlement list. `{ success, transactions[], count }` + `data`. |

`GET /api/lots` for a **RECYCLER** returns lots assigned to that recycler **or**
still unclaimed (`recycler_id IS NULL`), so Incoming Lots can accept work.

---

## 11. Notifications and price alerts

Both require a bearer token and return only the caller's own records.

- `/api/notifications` — collector notifications, with read/unread state.
- `/api/price-alerts` — collector price alerts.

---

## 12. AI gateway

### `POST /api/ai/analyze` — optional auth

`multipart/form-data` with an image file. The backend proxies to the Python AI
service; the collector never calls the AI service directly (AGENTS.md section 2).

| Part        | Type   | Required | Notes                          |
|-------------|--------|----------|--------------------------------|
| `file`      | image  | yes      | `image/*`, size-limited.       |
| `weight_kg` | number | no       | Optional known weight.         |
| `lot_id`    | string | no       | Attach the result to a lot.    |

The response is the **raw AI-service body** (snake_case), preserved so the
deployed collector keeps reading `material` and `confidence`:

```json
{
  "material": "pcb",
  "confidence": 0.95,
  "critical_mineral": true,
  "critical_mineral_reason": null,
  "model_version": "sih-5class-v1",
  "rule_version": "rules-1",
  "supported_materials": ["pcb", "battery", "cable", "crt", "lcd_panel"],
  "weight_estimate": { "estimated_weight_kg": 1.0, "confidence": 0.8, "method": "image" },
  "value_estimate": { "estimated_value_inr": 448, "confidence": 0.7, "rate_per_kg_inr": 448, "method": "rate_card" }
}
```

Error mapping: validation → `422`, upstream timeout → `504`, upstream
unreachable → `503`, missing file → `400` (`NO_IMAGE`).

AI output is an inference, not proof of elemental composition (AGENTS.md
section 7); clients must word critical-mineral results as "potential".

---

## 13. Graceful degradation (no database)

The process starts even when `DATABASE_URL` is not configured.

- `/health` (liveness), `/health/live`, and `POST /api/ai/analyze` work without a
  database.
- Every other `/api/*` route answers `503` with code `DATABASE_NOT_CONFIGURED`
  rather than a connection error.
- `/health/ready` reports `degraded` with per-dependency detail.
