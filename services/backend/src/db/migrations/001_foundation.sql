-- =====================================================================
-- 001 — Extensions, shared trigger function, audit timestamps
-- Reference: docs/database/schema.md
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- updated_at is maintained by the database so no application code can
-- forget to set it. Every mutable table opts in with this trigger.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Rows that form the traceability audit trail must never be edited or
-- deleted. This function is attached to several tables, so it reports
-- TG_TABLE_NAME rather than a hardcoded table — a message naming
-- "audit_records" while the failure was on traceability_events sent whoever
-- debugged it looking in the wrong place.
CREATE OR REPLACE FUNCTION prevent_audit_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: % on it is not permitted',
    TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END;
$$ LANGUAGE plpgsql;
