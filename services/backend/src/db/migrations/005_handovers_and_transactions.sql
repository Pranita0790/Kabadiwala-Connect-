-- =====================================================================
-- 005 — Recyclers, handovers, transactions
-- Handover statuses mirror the collector app's AppConstants.handover* and
-- transaction statuses mirror the proposed /api/transactions/my contract.
-- =====================================================================

CREATE TABLE IF NOT EXISTS recycler_profiles (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  organisation_name TEXT NOT NULL,
  address           TEXT,
  city              TEXT,
  region            TEXT,
  latitude          NUMERIC(9, 6),
  longitude         NUMERIC(9, 6),
  contact_phone     TEXT,
  -- Authorised recyclers are the ones the platform vouches for.
  is_authorized     BOOLEAN NOT NULL DEFAULT FALSE,
  rating            NUMERIC(2, 1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),
  accepts_mixed     BOOLEAN NOT NULL DEFAULT TRUE,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recycler_profiles_authorized
  ON recycler_profiles (is_active, is_authorized);

-- Attach the constraint that migration 004 could not declare inline, because
-- recycler_profiles did not exist yet at that point. See the note on the
-- column in 004: lots.recycler_id is a recycler PROFILE id.
ALTER TABLE lots
  DROP CONSTRAINT IF EXISTS lots_recycler_id_fkey;

ALTER TABLE lots
  ADD CONSTRAINT lots_recycler_id_fkey
  FOREIGN KEY (recycler_id) REFERENCES recycler_profiles (id) ON DELETE SET NULL;

-- Which material classes a recycler accepts. Drives recycler matching.
CREATE TABLE IF NOT EXISTS recycler_accepted_materials (
  recycler_id   UUID NOT NULL REFERENCES recycler_profiles (id) ON DELETE CASCADE,
  material_id   TEXT NOT NULL REFERENCES materials (id) ON DELETE CASCADE,
  PRIMARY KEY (recycler_id, material_id)
);

CREATE TABLE IF NOT EXISTS handovers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  -- Idempotency key from the offline device.
  client_reference  UUID UNIQUE,

  lot_id            UUID NOT NULL REFERENCES lots (id) ON DELETE RESTRICT,
  collector_id      UUID REFERENCES users (id) ON DELETE SET NULL,
  recycler_id       UUID REFERENCES recycler_profiles (id) ON DELETE SET NULL,

  material_category TEXT,
  weight_kg         NUMERIC(10, 3),
  agreed_amount     NUMERIC(12, 2) CHECK (agreed_amount IS NULL OR agreed_amount >= 0),
  currency          CHAR(3) NOT NULL DEFAULT 'INR',

  -- Opaque token embedded in the QR payload. It contains no personal data
  -- (see collector Handover.buildSafeQrPayload) and is verified server side.
  qr_token_hash     TEXT UNIQUE,
  qr_payload_version SMALLINT NOT NULL DEFAULT 1,

  status            TEXT NOT NULL DEFAULT 'PENDING_CONFIRMATION'
                      CHECK (status IN ('PENDING_CONFIRMATION', 'CONFIRMED', 'CANCELLED')),

  -- Both parties sign off; a single-sided confirmation is not a settlement.
  collector_confirmed_at  TIMESTAMPTZ,
  recycler_confirmed_at   TIMESTAMPTZ,
  confirmed_at      TIMESTAMPTZ,

  sync_status       TEXT NOT NULL DEFAULT 'SYNCED'
                      CHECK (sync_status IN ('PENDING_SYNC', 'SYNCING',
                                             'SYNCED', 'FAILED')),
  retry_count       SMALLINT NOT NULL DEFAULT 0,

  cancelled_reason  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_handovers_lot ON handovers (lot_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_handovers_collector
  ON handovers (collector_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_handovers_recycler
  ON handovers (recycler_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_handovers_pending
  ON handovers (created_at DESC) WHERE status = 'PENDING_CONFIRMATION';

DROP TRIGGER IF EXISTS trg_handovers_updated_at ON handovers;
CREATE TRIGGER trg_handovers_updated_at
  BEFORE UPDATE ON handovers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- The collector's earnings ledger. A transaction is created when a handover
-- is confirmed, and its settlement is recorded separately.
CREATE TABLE IF NOT EXISTS transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  lot_id            UUID NOT NULL REFERENCES lots (id) ON DELETE RESTRICT,
  handover_id       UUID REFERENCES handovers (id) ON DELETE SET NULL,
  collector_id      UUID REFERENCES users (id) ON DELETE SET NULL,
  recycler_id       UUID REFERENCES recycler_profiles (id) ON DELETE SET NULL,

  category_name     TEXT,
  weight_kg         NUMERIC(10, 3),

  quoted_price      NUMERIC(12, 2),
  final_price       NUMERIC(12, 2) CHECK (final_price IS NULL OR final_price >= 0),
  currency          CHAR(3) NOT NULL DEFAULT 'INR',

  -- Rate snapshot: the transaction must remain explainable even after the
  -- rate card changes.
  applied_rate_per_kg NUMERIC(12, 2),
  rate_id           UUID REFERENCES material_rates (id) ON DELETE SET NULL,

  payment_status    TEXT NOT NULL DEFAULT 'PENDING'
                      CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'DISPUTED')),
  handover_status   TEXT NOT NULL DEFAULT 'PENDING_CONFIRMATION'
                      CHECK (handover_status IN ('PENDING_CONFIRMATION',
                                                  'CONFIRMED', 'CANCELLED')),

  settled_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_collector
  ON transactions (collector_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_recycler
  ON transactions (recycler_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_lot ON transactions (lot_id);
CREATE INDEX IF NOT EXISTS idx_transactions_payment
  ON transactions (payment_status, created_at DESC);

DROP TRIGGER IF EXISTS trg_transactions_updated_at ON transactions;
CREATE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
