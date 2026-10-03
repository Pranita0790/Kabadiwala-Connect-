-- =====================================================================
-- 002 — Identity: users, roles, refresh tokens
-- Roles mirror packages/shared/contracts/enums.json -> userRole.
-- =====================================================================

CREATE TABLE IF NOT EXISTS users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  -- Nullable: a recycler-registered user is created by their organisation
  -- before they ever log in.
  phone             TEXT UNIQUE,
  email             TEXT UNIQUE,
  password_hash     TEXT,

  full_name         TEXT NOT NULL,
  role              TEXT NOT NULL
                      CHECK (role IN ('COLLECTOR', 'RECYCLER', 'ADMIN')),

  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified       BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at     TIMESTAMPTZ,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT users_need_an_identifier CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users (role) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_users_phone ON users (phone) WHERE phone IS NOT NULL;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- One-time-password verification. Rows are short lived and single use so a
-- replayed OTP cannot be used to take over an account.
CREATE TABLE IF NOT EXISTS otp_challenges (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  channel           TEXT NOT NULL CHECK (channel IN ('SMS', 'EMAIL')),
  destination       TEXT NOT NULL,
  code_hash         TEXT NOT NULL,
  attempts          SMALLINT NOT NULL DEFAULT 0,
  max_attempts      SMALLINT NOT NULL DEFAULT 5,
  consumed_at       TIMESTAMPTZ,
  expires_at        TIMESTAMPTZ NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_user_pending
  ON otp_challenges (user_id, created_at DESC)
  WHERE consumed_at IS NULL;

-- Refresh tokens are stored hashed: a database leak must not yield usable
-- sessions. `replaced_by_id` records the rotation chain so a stolen token
-- can be traced and revoked.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash        TEXT NOT NULL UNIQUE,
  expires_at        TIMESTAMPTZ NOT NULL,
  revoked_at        TIMESTAMPTZ,
  replaced_by_id    UUID REFERENCES refresh_tokens (id) ON DELETE SET NULL,
  user_agent        TEXT,
  ip_address        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
  ON refresh_tokens (user_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_active
  ON refresh_tokens (token_hash)
  WHERE revoked_at IS NULL;
