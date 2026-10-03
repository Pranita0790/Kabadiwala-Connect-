-- =====================================================================
-- 003 — Material catalogue and rate card
-- Material ids match the AI service MaterialName literals
-- (services/ai-service/app/models/material_analysis.py).
-- =====================================================================

CREATE TABLE IF NOT EXISTS materials (
  id                TEXT PRIMARY KEY,
  display_name      TEXT NOT NULL,
  category          TEXT NOT NULL,
  is_critical_mineral BOOLEAN NOT NULL DEFAULT FALSE,
  critical_mineral_reason TEXT,
  -- Classes the deployed sih-5class-v1 model can actually predict. A class
  -- outside this list may be in the catalogue but cannot come from the model.
  is_model_supported BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_materials_updated_at ON materials;
CREATE TRIGGER trg_materials_updated_at
  BEFORE UPDATE ON materials
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Rates are INR per kilogram. History is kept rather than overwritten so a
-- settled transaction can always be explained by the rate in force at the
-- time of settlement.
CREATE TABLE IF NOT EXISTS material_rates (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Stable public key used by the Recycler Dashboard rate board.
  -- e.g. "pcb", "lcd-panel".
  public_id         TEXT NOT NULL,
  material_id       TEXT NOT NULL REFERENCES materials (id) ON DELETE RESTRICT,
  region            TEXT NOT NULL DEFAULT 'IN-MH',
  rate_per_kg       NUMERIC(12, 2) NOT NULL CHECK (rate_per_kg >= 0),
  unit              TEXT NOT NULL DEFAULT 'INR/kg',
  source            TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  valid_from        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_to          TIMESTAMPTZ,
  created_by        UUID REFERENCES users (id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT material_rates_validity CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_material_rates_current
  ON material_rates (public_id, region)
  WHERE is_active AND valid_to IS NULL;

CREATE INDEX IF NOT EXISTS idx_material_rates_lookup
  ON material_rates (material_id, region, valid_from DESC);

DROP TRIGGER IF EXISTS trg_material_rates_updated_at ON material_rates;
CREATE TRIGGER trg_material_rates_updated_at
  BEFORE UPDATE ON material_rates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
