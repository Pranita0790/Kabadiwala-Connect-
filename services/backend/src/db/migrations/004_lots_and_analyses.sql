-- =====================================================================
-- 004 — Lots and AI analyses
-- The lot is the central traceability record. It is created offline on the
-- collector device and synchronised later, so client_reference is the
-- idempotency key that makes a retried sync safe.
-- =====================================================================

-- Sequence for human readable lot references (KC-2026-0148).
CREATE TABLE IF NOT EXISTS lot_number_sequences (
  year              INTEGER PRIMARY KEY,
  last_value        INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS lots (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  -- Client-generated UUID. UNIQUE makes POST /api/lots idempotent: an
  -- offline device that retries after a timeout re-uses the same value and
  -- the backend returns the existing row instead of duplicating it.
  client_reference  UUID UNIQUE,

  -- Human readable reference, e.g. KC-2026-0148.
  lot_number        TEXT UNIQUE,

  collector_id      UUID REFERENCES users (id) ON DELETE SET NULL,

  -- The recycler PROFILE id, not the recycler's user id. recycler_profiles
  -- is created in migration 005, so the foreign key is attached there with
  -- ALTER TABLE; declaring it here would fail because the table does not
  -- exist yet. Every other recycler-scoped table (handovers, transactions,
  -- recycler_accepted_materials) references recycler_profiles(id), and the
  -- auth repository resolves user.recyclerId to rp.id, so this column must
  -- agree or a recycler's ownership check silently never matches.
  --
  -- collector_id uses ON DELETE SET NULL because accounts are deactivated
  -- rather than deleted, so the link stays intact in normal operation.
  recycler_id       UUID,

  material_id       TEXT REFERENCES materials (id) ON DELETE SET NULL,
  category_name     TEXT,
  condition         TEXT CHECK (condition IN ('Scrap', 'Good', 'Partial')),

  weight_kg         NUMERIC(10, 3) CHECK (weight_kg IS NULL OR weight_kg > 0),

  status            TEXT NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED',
                                        'HANDOVER', 'COMPLETED')),

  -- Collector-side sync bookkeeping, mirrored from the device.
  sync_status       TEXT NOT NULL DEFAULT 'SYNCED'
                      CHECK (sync_status IN ('PENDING_SYNC', 'SYNCING',
                                             'SYNCED', 'FAILED')),

  -- AI inference result. Always an inference, never proof of composition
  -- (AGENTS.md section 7), which is why the model and rule versions are
  -- stored alongside the prediction.
  ai_confidence        NUMERIC(5, 4) CHECK (ai_confidence IS NULL
                                          OR (ai_confidence >= 0 AND ai_confidence <= 1)),
  critical_mineral     BOOLEAN,
  critical_mineral_reason TEXT,
  model_version        TEXT,
  rule_version         TEXT,
  image_path           TEXT,

  -- Indicative value, recomputed whenever weight or rate changes.
  estimated_value      NUMERIC(12, 2),
  estimated_min_value  NUMERIC(12, 2),
  estimated_max_value  NUMERIC(12, 2),
  estimated_currency   CHAR(3) NOT NULL DEFAULT 'INR',
  estimated_at         TIMESTAMPTZ,

  notes             TEXT,
  collection_address TEXT,
  collection_latitude  NUMERIC(9, 6),
  collection_longitude NUMERIC(9, 6),

  -- Optimistic concurrency: the sync endpoint uses this to detect that the
  -- record changed on the server while the device was offline.
  version           INTEGER NOT NULL DEFAULT 1,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rejected_at       TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,

  -- Soft delete: a traceability record must never be hard deleted
  -- (AGENTS.md section 8).
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_lots_collector ON lots (collector_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lots_recycler ON lots (recycler_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lots_status ON lots (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lots_material ON lots (material_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lots_live ON lots (created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lots_critical
  ON lots (created_at DESC)
  WHERE critical_mineral AND deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_lots_updated_at ON lots;
CREATE TRIGGER trg_lots_updated_at
  BEFORE UPDATE ON lots
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- One AI inference per submission. Keeping each inference separately is what
-- makes a later dispute ("why was this called a PCB?") answerable.
CREATE TABLE IF NOT EXISTS ai_analyses (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id            UUID REFERENCES lots (id) ON DELETE CASCADE,
  collector_id      UUID REFERENCES users (id) ON DELETE SET NULL,

  -- Path used for the request, for auditing. The image itself is not stored
  -- in the database.
  source            TEXT NOT NULL DEFAULT 'IMAGE',
  image_filename    TEXT,
  image_size_bytes  INTEGER,

  material_predicted TEXT,
  confidence        NUMERIC(5, 4) CHECK (confidence IS NULL
                                        OR (confidence >= 0 AND confidence <= 1)),
  is_low_confidence BOOLEAN NOT NULL DEFAULT FALSE,

  critical_mineral     BOOLEAN,
  critical_mineral_reason TEXT,

  weight_estimate_value NUMERIC(10, 3),
  value_estimate_min    NUMERIC(12, 2),
  value_estimate_max    NUMERIC(12, 2),

  model_version   TEXT,
  rule_version    TEXT,
  latency_ms      INTEGER,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_analyses_lot ON ai_analyses (lot_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_analyses_collector
  ON ai_analyses (collector_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_analyses_low_confidence
  ON ai_analyses (created_at DESC) WHERE is_low_confidence;
