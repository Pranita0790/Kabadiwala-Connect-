/*
|--------------------------------------------------------------------------
| AI ANALYSES REPOSITORY
|--------------------------------------------------------------------------
| Persists each inference so a classification can be explained after the
| fact: which model, which rules, which confidence, which wording.
|
| The image itself is never stored — only its filename and size. Storing
| field photographs of collectors' material would create a privacy and
| storage problem with no analytical benefit, since the inference is already
| captured in these columns.
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, insertOne } = require("../../db/query");

function toAnalysis(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    lotId: row.lot_id,
    source: row.source,
    materialPredicted: row.material_predicted,
    confidence: row.confidence === null ? null : Number(row.confidence),
    isLowConfidence: row.is_low_confidence,
    criticalMineral: row.critical_mineral,
    criticalMineralReason: row.critical_mineral_reason,
    weightEstimate: {
      value: row.weight_estimate_value === null
        ? null
        : Number(row.weight_estimate_value),
    },
    valueEstimate: {
      min: row.value_estimate_min === null ? null : Number(row.value_estimate_min),
      max: row.value_estimate_max === null ? null : Number(row.value_estimate_max),
    },
    modelVersion: row.model_version,
    ruleVersion: row.rule_version,
    latencyMs: row.latency_ms,
    createdAt: row.created_at,
  };
}

async function create(analysis) {
  const row = await insertOne(
    "ai_analyses",
    {
      lot_id: analysis.lotId ?? null,
      collector_id: analysis.collectorId ?? null,
      source: analysis.source ?? "IMAGE",
      image_filename: analysis.imageFilename ?? null,
      image_size_bytes: analysis.imageSizeBytes ?? null,
      material_predicted: analysis.materialPredicted ?? null,
      confidence: analysis.confidence ?? null,
      is_low_confidence: analysis.isLowConfidence ?? false,
      critical_mineral: analysis.criticalMineral ?? null,
      critical_mineral_reason: analysis.criticalMineralReason ?? null,
      weight_estimate_value: analysis.weightEstimateValue ?? null,
      value_estimate_min: analysis.valueEstimateMin ?? null,
      value_estimate_max: analysis.valueEstimateMax ?? null,
      model_version: analysis.modelVersion ?? null,
      rule_version: analysis.ruleVersion ?? null,
      latency_ms: analysis.latencyMs ?? null,
    },
    { label: "aiAnalyses:create" }
  );

  return toAnalysis(row);
}

async function listForLot(lotId) {
  const rows = await queryRows(
    `SELECT * FROM ai_analyses
     WHERE lot_id = $1
     ORDER BY created_at DESC`,
    [lotId],
    { label: "aiAnalyses:listForLot" }
  );

  return rows.map(toAnalysis);
}

async function latestForLot(lotId) {
  const row = await queryOne(
    `SELECT * FROM ai_analyses
     WHERE lot_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [lotId],
    { label: "aiAnalyses:latestForLot" }
  );

  return toAnalysis(row);
}

/**
 * Inferences the platform should review: low confidence, or a critical
 * mineral claim on a non-critical-catalogue material.
 */
async function listNeedingReview({ limit = 25, offset = 0 } = {}) {
  const rows = await queryRows(
    `SELECT a.*, l.lot_number, l.public_id AS lot_public_id
     FROM ai_analyses a
     JOIN lots l ON l.id = a.lot_id
     WHERE l.deleted_at IS NULL
       AND (a.is_low_confidence OR (a.critical_mineral AND NOT l.critical_mineral))
     ORDER BY a.created_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset],
    { label: "aiAnalyses:listNeedingReview" }
  );

  return rows.map((row) => ({
    ...toAnalysis(row),
    lotNumber: row.lot_number,
    lotId: row.lot_public_id,
  }));
}

module.exports = {
  create,
  listForLot,
  latestForLot,
  listNeedingReview,
  toAnalysis,
};