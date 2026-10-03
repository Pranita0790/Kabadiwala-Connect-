/*
|--------------------------------------------------------------------------
| AI SERVICE (backend module)
|--------------------------------------------------------------------------
| Gateway between the collector app and the Python AI service. The device
| never calls FastAPI directly (AGENTS.md section 2); it calls this module,
| which forwards the image through clients/ai-service.client.js.
|
| Two design points:
|
|   1. The response returned to the client is the RAW FastAPI body, unchanged.
|      The deployed collector parses `material` and `confidence` from the top
|      level and the engine's own field names are part of the frozen contract
|      (AGENTS.md section 5), so the gateway must not rename them.
|
|   2. Persisting the inference is BEST-EFFORT and never fails the request.
|      Classification is useful with no database at all (the collector can
|      still show a category), so a missing or broken database must not take
|      the AI gateway down with it.
|--------------------------------------------------------------------------
*/

const aiClient = require("../../clients/ai-service.client");
const aiAnalysesRepository = require("../lots/ai-analyses.repository");
const config = require("../../config/env");
const logger = require("../../lib/logger");
const { deployedModel } = require("../../config/constants");

/**
 * Classify an uploaded image.
 *
 * @param {object} params
 * @param {object} params.file     multer file ({ buffer, originalname, mimetype, size })
 * @param {number} [params.weightKg]
 * @param {string} [params.lotId]  Optional lot identifier to attach to
 * @param {object} [params.user]   Authenticated caller, when a token was sent
 * @returns {{analysis: object, latencyMs: number}}
 */
async function analyze({ file, weightKg, lotId = null, user = null }) {
  const { raw, latencyMs } = await aiClient.analyzeMaterialRaw({
    fileBuffer: file.buffer,
    filename: file.originalname,
    mimetype: file.mimetype,
    weightKg,
  });

  await persistBestEffort({ raw, latencyMs, lotId, user, file });

  return { analysis: raw, latencyMs };
}

async function persistBestEffort({ raw, latencyMs, lotId, user, file }) {
  if (!config.database.configured) {
    return;
  }

  try {
    const confidence =
      typeof raw?.confidence === "number" ? raw.confidence : null;

    await aiAnalysesRepository.create({
      lotId: lotId || null,
      collectorId: user?.id ?? null,
      imageFilename: file?.originalname ?? null,
      imageSizeBytes: file?.size ?? null,
      materialPredicted: raw?.material ?? null,
      confidence,
      isLowConfidence:
        confidence !== null && confidence < deployedModel.confidenceThreshold,
      criticalMineral:
        typeof raw?.critical_mineral === "boolean" ? raw.critical_mineral : null,
      criticalMineralReason: raw?.critical_mineral_reason ?? null,
      weightEstimateValue: raw?.weight_estimate?.estimated_weight_kg ?? null,
      valueEstimateMin: null,
      valueEstimateMax: raw?.value_estimate?.estimated_value_inr ?? null,
      modelVersion: raw?.model_version ?? null,
      ruleVersion: raw?.rule_version ?? null,
      latencyMs: latencyMs ?? null,
    });
  } catch (error) {
    // Logged, never surfaced: the inference already succeeded.
    logger.warn("Failed to persist AI analysis", {
      message: error.message,
      lotId,
    });
  }
}

module.exports = { analyze };
