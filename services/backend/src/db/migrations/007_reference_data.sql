-- =====================================================================
-- 007 — Reference data: material catalogue and seed rate card
--
-- Rate values are carried over unchanged from the previous
-- services/backend/src/data/rates.json so the deployed Recycler Dashboard
-- rate board keeps showing the same numbers after this migration.
-- This is reference data, not production data, so it is safe to re-apply:
-- every statement is idempotent.
-- =====================================================================

-- Material ids use SNAKE_CASE and must match the deployed AI service's
-- MaterialName literals exactly (services/ai-service/app/models/
-- material_analysis.py), because the AI response is what populates
-- lots.material_id. Do not "tidy" these to kebab-case: the AI service emits
-- `lcd_panel`, not `lcd-panel`, and the mismatch would break every rate
-- lookup and price alert for that material.
--
-- `is_model_supported` marks only the classes the deployed sih-5class-v1
-- model can predict; the rest remain valid lot categories entered manually.
INSERT INTO materials
  (id, display_name, category, is_critical_mineral, critical_mineral_reason, is_model_supported)
VALUES
  ('pcb', 'PCB / Motherboard', 'E-Waste', TRUE,
   'Potential copper and precious-metal-bearing traces. Rule-based inference, not laboratory analysis.',
   TRUE),
  ('battery', 'Battery', 'Critical Material', TRUE,
   'Potential lithium or lead chemistry. Rule-based inference, not laboratory analysis.',
   TRUE),
  ('crt', 'CRT', 'E-Waste', FALSE, NULL, TRUE),
  ('lcd_panel', 'LCD Panel', 'E-Waste', FALSE, NULL, TRUE),
  ('cable', 'Cable', 'Copper', FALSE, NULL, TRUE),
  ('motor', 'Motor', 'Metal', FALSE, NULL, FALSE),
  ('magnet_bearing_assembly', 'Magnet / Bearing Assembly', 'Critical Material', TRUE,
   'Potential rare-earth bearing magnets. Rule-based inference, not laboratory analysis.',
   FALSE),
  ('mixed_plastics', 'Mixed Plastics', 'Plastic', FALSE, NULL, FALSE)
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  category = EXCLUDED.category,
  is_critical_mineral = EXCLUDED.is_critical_mineral,
  critical_mineral_reason = EXCLUDED.critical_mineral_reason,
  is_model_supported = EXCLUDED.is_model_supported,
  updated_at = NOW();

-- public_id values match the ids the deployed rate board already stores in
-- localStorage, so saved rows still match after the move to PostgreSQL.
INSERT INTO material_rates
  (public_id, material_id, region, rate_per_kg, unit, source, is_active, valid_from)
VALUES
  ('pcb',                     'pcb',                     'IN-MH', 448.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('battery',                 'battery',                 'IN-MH', 100.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('cable',                   'cable',                   'IN-MH', 396.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('lcd_panel',               'lcd_panel',               'IN-MH', 180.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('crt',                     'crt',                     'IN-MH',  85.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('motor',                   'motor',                   'IN-MH', 220.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('magnet_bearing_assembly', 'magnet_bearing_assembly', 'IN-MH', 350.00, 'INR/kg', 'SEED', TRUE, NOW()),
  ('mixed_plastics',           'mixed_plastics',          'IN-MH',  45.00, 'INR/kg', 'SEED', TRUE, NOW())
ON CONFLICT DO NOTHING;
