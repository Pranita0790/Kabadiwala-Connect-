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
- **Roles** — `COLLECTOR`, `USER`, `RECYCLER`, `ADMIN`. Authorization is enforced
  on the backend. Mobile apps may request a role at **register** only
  (`COLLECTOR` or `USER`); they cannot escalate after sign-up.

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

Password login for accounts that have a password (collector app, household user
app, or recycler dashboard).

| Field        | Type   | Required | Notes |
|--------------|--------|----------|-------|
| `identifier` | string | yes      | Phone (any Indian format) or email. |
| `password`   | string | yes      | Account password. |
| `app`        | string | no       | `collector` → `COLLECTOR` **or** `USER`; `user` → `USER` only. Omit for dashboard/any role. |

- Wrong-app login returns **403** (`FORBIDDEN`) — e.g. a `RECYCLER` cannot use
  the collector mobile login, and a `COLLECTOR` cannot use the household user app.
- A collector account has no `password_hash`. Requesting password login for one
  returns an error with code `FIREBASE_SIGN_IN_REQUIRED` so the client knows to
  use the Firebase flow.

### `POST /api/auth/register` — public

Creates a password account for the collector or household user apps.

| Field      | Type   | Required | Notes |
|------------|--------|----------|-------|
| `fullName` | string | yes      | Display name. |
| `phone`    | string | yes      | Indian mobile. |
| `password` | string | yes      | Min 8 characters. |
| `role`     | string | no       | `COLLECTOR` (default) or `USER`. |
| `email`    | string | no       | Optional. |

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
| `POST`  | `/api/lots/sync`          | COLLECTOR, RECYCLER, ADMIN | Batch offline sync; idempotent per `clientId`.|
| `POST`  | `/api/lots`               | COLLECTOR, RECYCLER, ADMIN | Create. `201` when newly created.            |
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
| `POST` | `/api/handovers` | COLLECTOR, RECYCLER, ADMIN | Create handover for a lot. Body accepts camelCase or collector snake_case (`lot_id`, `agreed_amount`, …). Idempotent on `clientReference` / UUID `id`. If the lot is missing, a collector/admin request auto-creates an idempotent lot from the handover payload (`lotId` as `clientReference`) so offline sync can complete. |
| `POST` | `/api/handovers/:id/confirm` | COLLECTOR, RECYCLER, ADMIN | Dual confirmation. `:id` may be the handover `public_id`, collector `client_reference`, **or the lot** public id / lot number. Recyclers completing payment from the website should send `{ "completeBoth": true, "paymentMethod": "CASH"|"UPI" }`. When both sides confirm, creates a `transactions` row (`paymentStatus: PAID`), notifies the collector, and moves the lot toward `COMPLETED`. |
| `GET` | `/api/transactions/my` | COLLECTOR, RECYCLER, ADMIN | Collector earnings ledger / recycler settlement list. `{ success, transactions[], count }` + `data`. |

`GET /api/lots` for a **RECYCLER** returns lots assigned to that recycler **or**
still unclaimed (`recycler_id IS NULL`), so Incoming Lots can accept work.

Lot payloads include `clientReference` (offline collector UUID) when present.
The collector handover PIN is derived from `clientReference` (not `id` /
`lotNumber`); the recycler website must accept a PIN matching
`clientReference`, falling back to `id` for older rows.

---

## 11. Notifications and price alerts

Both require a bearer token and return only the caller's own records.

- `/api/notifications` — collector notifications, with read/unread state.
- `/api/price-alerts` — collector price alerts.

---

## 11b. Customer pickup workflow (collector app)

These endpoints power the collector **customer / pickup** screens. They are
in-memory on the Node gateway today (no Postgres table yet) and stay usable
when the database is down. The Flutter app still caches rows in SQLite.

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `GET` | `/api/pickup-requests` | optional | `{ success, data: { requests[], count } }`. Filter with `?status=`. |
| `GET` | `/api/pickup-requests/:id` | optional | `{ success, data: { request } }`. |
| `POST` | `/api/pickup-requests` | optional | Create. Body camelCase (`userName`, `pickupAddress`, `estimatedWeightKg`, `ratePerKg`, …). |
| `PATCH` | `/api/pickup-requests/:id/status` | optional | Status: `PENDING`, `ACCEPTED`, `ON_MY_WAY`, `COLLECTING`, `COMPLETED`, `REJECTED`, `CANCELLED`. |
| `POST` | `/api/pickup-requests/:id/complete` | optional | Body `{ actualWeightKg, paymentMethod }`. `finalAmount = actualWeightKg * ratePerKg`. |
| `GET` | `/api/collector-rates` | optional | Collector-owned rate card `{ success, data: { rates[], count } }`. Optional `?collectorId=` (or collector JWT) filters to that kabadiwala; falls back to seed `default_collector` rates when empty. |
| `POST` | `/api/collector-rates` | optional | Create/replace a rate. When a COLLECTOR JWT is present, `collectorId` is bound to that user's `publicId` so household `/api/user/vendors` can show the live rate card. |
| `DELETE` | `/api/collector-rates/:id` | optional | Soft-deletes (`isActive: false`). Collectors may only delete their own rates. |

This is separate from recycler market rates (`GET /api/rates`).

---

## 11c. Household user app (`apps/user`)

In-memory Node gateway APIs for the Flutter **user** (household) app.
Requires a database-backed JWT from the **shared** auth system
(`POST /api/auth/login` with `app: "user"`, role `USER`). Creating a request
also mirrors into `/api/pickup-requests` so the collector app can see it.

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `GET` | `/api/user/vendors` | USER bearer | Nearby kabadiwalas from live `COLLECTOR` accounts (+ local seed), sorted nearest-first. Optional query `category` / `material` (`Paper` \| `Metal` \| `Plastic` \| `E-waste` \| `Other`). Response `{ success, data: { vendors[], count, categories[] } }` where each vendor includes `id` (collector `publicId`), `name`, `phone`, `address`, `city`, `distanceKm`, `rating`, `acceptedMaterials[]`, `rates` (category summary), `rateCard[]` (`materialName`, `materialCategory`, `ratePerKg` from collector rate card), `isCollector`. Live collectors always appear ahead of seed fillers. |
| `GET` | `/api/user/requests` | USER bearer | User-created sell/pickup requests. |
| `GET` | `/api/user/requests/:id` | USER bearer | Single request for status polling after collector Accept/Reject. |
| `POST` | `/api/user/requests` | USER bearer | Create request (camelCase body). Also ingested into collector pickup queue as `PENDING` for Accept/Reject. Collector `PATCH /api/pickup-requests/:id/status` syncs mapped status back (`ACCEPTED`→`KABADIWALA_ACCEPTED`, `REJECTED`→`REJECTED`, `ON_MY_WAY`→`PICKUP_SCHEDULED`, `COMPLETED`→`AMOUNT_CALCULATED`). |
| `GET` | `/api/payment-config` | none | Shared Razorpay Checkout config for **collector + user** apps. Returns `{ razorpayKeyId, mode, configured }` — **Key Id only** (from `RAZORPAY_KEY_ID`). Never returns the Key Secret. |
| `GET` | `/api/user/payment-config` | USER bearer | Same Key Id payload for the household user app (authenticated). |
| `GET` | `/api/user/payments` | USER bearer | Payment history seed data. |
| `GET` | `/api/user/collections` | USER bearer | Past collection records. |

---

## 11d. Loyalty — favorite, regular customer, reminders, referral

In-memory gateway (`services/backend/src/modules/loyalty`). Requires a
database-backed JWT (`requireAuth`). Threshold: **≥ 5 completed purchases**
with the same kabadiwala → `isFavorite` (user) + `isRegular` (collector).
Referral: **₹20 + ₹20** after the referred user's first completed purchase.
Reminders are collector-initiated (WEEK / MONTH) with a **6-day cooldown**.

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `POST` | `/api/loyalty/chooses` | USER | Body `{ collectorId }`. Increments choose count. |
| `POST` | `/api/loyalty/purchases` | USER or COLLECTOR | Body `{ collectorId, requestId, amount, userId? }`. Idempotent on `requestId`. Also mirrored from `POST /api/pickup-requests/:id/complete`. |
| `GET` | `/api/loyalty/me` | USER | Favorites, relations, referral profile, credits ledger, loyalty notifications. |
| `GET` | `/api/loyalty/customers` | COLLECTOR | Customers with `completedCount`, `isRegular`, `daysInactive`, `suggestedCadence` (`WEEK` if ≥7d, `MONTH` if ≥30d). |
| `POST` | `/api/loyalty/reminders` | COLLECTOR | Body `{ userId, cadence: "WEEK"\|"MONTH" }`. Creates USER in-app notification (raddi/paper/scrap copy). |
| `POST` | `/api/loyalty/referral/apply` | USER | Body `{ code }` e.g. `KC-XXXX`. |
| `GET` | `/api/loyalty/referral` | USER | Own code, credits, earnings. |
| `GET` | `/api/loyalty/notifications` | USER or COLLECTOR | In-app loyalty notifications. |
| `PATCH` | `/api/loyalty/notifications/:id/read` | USER or COLLECTOR | Mark one notification read. |

---

## 12. AI gateway

### `POST /api/ai/analyze` — optional auth

`multipart/form-data` with an image file. The backend tries **Google Gemini** first when `GEMINI_API_KEY` is set, then
falls back to the Python AI service. The collector never calls Gemini or
Python directly (AGENTS.md section 2). Response shape is unchanged so the
camera screen can fill Create Lot fields. Create Lot itself does **not**
run classification.

| Part        | Type   | Required | Notes                          |
|-------------|--------|----------|--------------------------------|
| `file`      | image  | yes      | `image/*`, size-limited.       |
| `weight_kg` | number | no       | Optional known weight.         |
| `lot_id`    | string | no       | Attach the result to a lot.    |

The response is the **same snake_case body**. Existing clients keep reading
`material` and `confidence`. Additive fields map the inference onto collector
lot categories. The camera screen may pre-fill Create Lot from this JSON;
Create Lot does not call analyze.

```json
{
  "material": "pcb",
  "confidence": 0.95,
  "category": "Motherboard / PCB",
  "category_id": "pcb_motherboard",
  "electronic_device": "Printed circuit board",
  "short_description": "Circuit board with chips and copper traces; best match is Motherboard / PCB.",
  "critical_mineral": true,
  "critical_mineral_reason": null,
  "model_version": "sih-5class-v1",
  "rule_version": "rules-1",
  "supported_materials": ["pcb", "battery", "cable", "crt", "lcd_panel", "mixed_plastics", "paper", "book"],
  "weight_estimate": { "estimated_weight_kg": 1.0, "confidence": 0.8, "method": "image" },
  "value_estimate": { "estimated_value_inr": 448, "confidence": 0.7, "rate_per_kg_inr": 448, "method": "rate_card" },
  "suggested_condition": "average",
  "suggestions": [
    "This looks like a circuit board / converter module.",
    "Save as Motherboard / PCB for a better rate."
  ]
}
```

Error mapping: validation → `422`, upstream timeout → `504`, upstream
unreachable → `503`, missing file → `400` (`NO_IMAGE`).

AI output is an inference, not proof of elemental composition (AGENTS.md
section 7); clients must word critical-mineral results as "potential".

---

## 13. Graceful degradation (no database)

The process starts even when `DATABASE_URL` is not configured.

- `/health` (liveness), `/health/live`, `POST /api/ai/analyze`,
  `/api/pickup-requests`, and `/api/collector-rates` work without a database.
- `/api/user/*` needs the database (shared JWT auth).
- Every other `/api/*` route answers `503` with code `DATABASE_NOT_CONFIGURED`
  rather than a connection error.
- `/health/ready` reports `degraded` with per-dependency detail.
