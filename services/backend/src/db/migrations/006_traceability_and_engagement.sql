-- =====================================================================
-- 006 — Traceability timeline, notifications, price alerts
-- =====================================================================

-- Append-only event log. A lot's journey is reconstructed by ordering these
-- rows; nothing in the log is ever updated or deleted.
CREATE TABLE IF NOT EXISTS traceability_events (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id            UUID NOT NULL REFERENCES lots (id) ON DELETE CASCADE,
  handover_id       UUID REFERENCES handovers (id) ON DELETE SET NULL,

  -- Ordered position in the journey, so stages sort deterministically even
  -- when two events share a timestamp.
  sequence_no       INTEGER NOT NULL,

  stage             TEXT NOT NULL
                      CHECK (stage IN ('Collection', 'Verification', 'Handover',
                                       'Processing', 'Completed')),
  event_status      TEXT NOT NULL DEFAULT 'pending'
                      CHECK (event_status IN ('completed', 'current', 'pending')),
  title             TEXT NOT NULL,
  description       TEXT,

  -- Who/what caused the event. "Kabadiwala AI Engine" is a valid actor, so
  -- this is not a user foreign key.
  actor             TEXT,
  actor_type        TEXT NOT NULL DEFAULT 'SYSTEM'
                      CHECK (actor_type IN ('COLLECTOR', 'RECYCLER', 'AI', 'SYSTEM')),
  location          TEXT,

  -- Immutable copy of the lot status at the time of the event.
  lot_status_at_event TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT traceability_events_sequence_unique UNIQUE (lot_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS idx_traceability_events_lot
  ON traceability_events (lot_id, sequence_no);

DROP TRIGGER IF EXISTS trg_traceability_events_append_only
  ON traceability_events;
CREATE TRIGGER trg_traceability_events_append_only
  BEFORE UPDATE OR DELETE ON traceability_events
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();

CREATE TABLE IF NOT EXISTS notifications (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  user_id           UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  lot_id            UUID REFERENCES lots (id) ON DELETE CASCADE,

  type              TEXT NOT NULL
                      CHECK (type IN ('HANDOVER_CONFIRMED', 'PRICE_ALERT',
                                      'LOT_STATUS', 'EPR', 'SYSTEM')),

  -- Localised copy. The collector app renders hi/en/mr, so the English text
  -- is authoritative and the translations are optional.
  title_en          TEXT NOT NULL,
  title_hi          TEXT,
  title_mr          TEXT,
  body_en           TEXT NOT NULL,
  body_hi           TEXT,
  body_mr           TEXT,

  is_read           BOOLEAN NOT NULL DEFAULT FALSE,
  read_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON notifications (user_id, created_at DESC) WHERE NOT is_read;

CREATE TABLE IF NOT EXISTS price_alerts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id         UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),

  user_id           UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  material_id       TEXT NOT NULL REFERENCES materials (id) ON DELETE CASCADE,
  region            TEXT NOT NULL DEFAULT 'IN-MH',

  -- A collector may care about "at least 300" or "no more than 200".
  target_rate_per_kg NUMERIC(12, 2) NOT NULL CHECK (target_rate_per_kg >= 0),
  direction         TEXT NOT NULL DEFAULT 'ABOVE'
                      CHECK (direction IN ('ABOVE', 'BELOW')),

  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  triggered_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_price_alerts_user
  ON price_alerts (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_price_alerts_active
  ON price_alerts (material_id, target_rate_per_kg) WHERE is_active;

DROP TRIGGER IF EXISTS trg_price_alerts_updated_at ON price_alerts;
CREATE TRIGGER trg_price_alerts_updated_at
  BEFORE UPDATE ON price_alerts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
