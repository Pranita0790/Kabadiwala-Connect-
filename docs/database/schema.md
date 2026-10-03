# Kabadiwala Connect — Database Schema

PostgreSQL. The backend is the only writer (AGENTS.md sections 2 and 8). Schema
changes are additive migrations under `services/backend/src/db/migrations/`,
numbered and applied in order; every migration is written to be safe on an
existing database (`IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`).

```text
001_foundation.sql              extensions, helper triggers (set_updated_at)
002_identity.sql                users, otp_challenges, refresh_tokens
003_catalog_and_rates.sql       materials, rates
004_lots_and_analyses.sql       e-waste lots, AI analyses
005_handovers_and_transactions.sql
006_traceability_and_engagement.sql
007_reference_data.sql
008_firebase_linkage.sql        users.firebase_uid
```

This document covers the **identity** tables in detail (the part touched by the
Firebase phone-auth work). Domain tables are documented alongside their
migrations.

---

## `users`

Platform accounts. A user is identified by a phone number and/or an email, and
has exactly one role.

| Column           | Type          | Constraints / notes                                          |
|------------------|---------------|--------------------------------------------------------------|
| `id`             | UUID          | PK, `gen_random_uuid()`                                      |
| `public_id`      | UUID          | UNIQUE, exposed to clients as `id` (never the internal `id`) |
| `phone`          | TEXT          | UNIQUE, nullable, E.164 (`+91XXXXXXXXXX`)                    |
| `email`          | TEXT          | UNIQUE, nullable                                             |
| `password_hash`  | TEXT          | nullable — Firebase phone accounts have none                  |
| `firebase_uid`   | TEXT          | nullable, see below                                          |
| `full_name`      | TEXT          | NOT NULL                                                     |
| `role`           | TEXT          | `COLLECTOR` \| `USER` \| `RECYCLER` \| `ADMIN`               |
| `is_active`      | BOOLEAN       | default TRUE                                                 |
| `is_verified`    | BOOLEAN       | default FALSE; phone sign-in sets TRUE                       |
| `last_login_at`  | TIMESTAMPTZ   | nullable                                                     |
| `created_at`     | TIMESTAMPTZ   | default NOW()                                                |
| `updated_at`     | TIMESTAMPTZ   | default NOW(), maintained by `trg_users_updated_at`          |

Constraints:

- `users_need_an_identifier` — `phone IS NOT NULL OR email IS NOT NULL`.
- `idx_users_role` — partial, `WHERE is_active`.
- `idx_users_phone` — partial, `WHERE phone IS NOT NULL`.

### `firebase_uid` (migration 008)

Stores the Firebase Identity Platform user id — the `sub` claim of the Firebase
ID token — for phone sign-in.

| Property        | Value                                                        |
|-----------------|--------------------------------------------------------------|
| Type            | `TEXT`                                                       |
| Nullable        | **yes** — password/recycler accounts predate Firebase        |
| Uniqueness      | `idx_users_firebase_uid`, partial `WHERE firebase_uid IS NOT NULL` |
| Indexed         | yes                                                          |

Design notes:

- **Unique** so one Firebase identity cannot map to two platform accounts.
- **Partial** because PostgreSQL already allows many NULLs; the partial index
  keeps it explicit and small.
- **Nullable** because accounts are created before any Firebase sign-in
  (recyclers are created by their organisation). `password_hash` is therefore
  also nullable.
- **No secret is stored.** Verification uses Google's public certificates, so
  no service-account key or admin credential exists in the database or the
  repo (AGENTS.md section 9).

---

## `otp_challenges`

Short-lived, single-use codes for **email** verification. SMS is handled by
Firebase and does not use this table.

| Column        | Type        | Notes                                             |
|---------------|-------------|---------------------------------------------------|
| `id`          | UUID        | PK                                                |
| `user_id`     | UUID        | FK → `users.id`, ON DELETE CASCADE                |
| `channel`     | TEXT        | `SMS` \| `EMAIL` (SMS rows are no longer created) |
| `destination` | TEXT        | the address the code was sent to                  |
| `code_hash`   | TEXT        | hashed, never the code in clear                   |
| `attempts`    | SMALLINT    | default 0                                         |
| `max_attempts`| SMALLINT    | default 5                                         |
| `consumed_at` | TIMESTAMPTZ | set on use; single use                            |
| `expires_at`  | TIMESTAMPTZ | NOT NULL                                          |
| `created_at`  | TIMESTAMPTZ | default NOW()                                     |

Index: `idx_otp_user_pending` on `(user_id, created_at DESC) WHERE consumed_at IS NULL`.

---

## `refresh_tokens`

Platform refresh tokens, stored **hashed** so a database leak yields no usable
session.

| Column           | Type        | Notes                                          |
|------------------|-------------|------------------------------------------------|
| `id`             | UUID        | PK                                             |
| `user_id`        | UUID        | FK → `users.id`, ON DELETE CASCADE             |
| `token_hash`     | TEXT        | UNIQUE, hashed                                 |
| `expires_at`     | TIMESTAMPTZ | NOT NULL                                       |
| `revoked_at`     | TIMESTAMPTZ | nullable                                       |
| `replaced_by_id` | UUID        | FK → `refresh_tokens.id`, rotation chain       |
| `user_agent`     | TEXT        | nullable, request context                      |
| `ip_address`     | TEXT        | nullable, request context                      |
| `created_at`     | TIMESTAMPTZ | default NOW()                                  |

Indexes: `idx_refresh_tokens_user`, `idx_refresh_tokens_active` (partial,
`WHERE revoked_at IS NULL`).

---

## Data integrity rules

- Never delete production data from a development script.
- The internal `users.id` is never exposed; clients see `public_id`.
- Identity changes (linking `firebase_uid`) are guarded so a race cannot attach
  one Firebase identity to two rows.
- Secrets (passwords, tokens, service keys) are stored hashed or not at all.
