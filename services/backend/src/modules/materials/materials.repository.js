/*
|--------------------------------------------------------------------------
| MATERIALS REPOSITORY
|--------------------------------------------------------------------------
| Read access to the material catalogue. The catalogue is reference data,
| seeded by migration 007; it is not edited through the public API.
|
| `id` values match the AI service's MaterialName literals so a prediction
| maps to a catalogue row without a translation table
| (services/ai-service/app/models/material_analysis.py).
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne } = require("../../db/query");

function toMaterial(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    displayName: row.display_name,
    category: row.category,
    isCriticalMineral: row.is_critical_mineral,
    // Never presented as proof of composition; see the reason text.
    criticalMineralReason: row.critical_mineral_reason,
    // True only for the classes the deployed sih-5class-v1 model predicts.
    isModelSupported: row.is_model_supported,
  };
}

async function list({ modelSupportedOnly = false } = {}) {
  const rows = await queryRows(
    `SELECT * FROM materials
     ${modelSupportedOnly ? "WHERE is_model_supported" : ""}
     ORDER BY category, display_name`,
    [],
    { label: "materials:list" }
  );

  return rows.map(toMaterial);
}

async function findById(id) {
  const row = await queryOne(
    "SELECT * FROM materials WHERE id = $1",
    [id],
    { label: "materials:findById" }
  );

  return toMaterial(row);
}

async function exists(id) {
  const row = await queryOne(
    "SELECT 1 AS present FROM materials WHERE id = $1",
    [id],
    { label: "materials:exists" }
  );

  return row !== null;
}

module.exports = { list, findById, exists, toMaterial };