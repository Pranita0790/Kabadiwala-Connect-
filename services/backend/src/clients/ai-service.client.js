/*
|--------------------------------------------------------------------------
| AI SERVICE CLIENT
|--------------------------------------------------------------------------
| The only place in this codebase that talks to the Python FastAPI service.
|
| Architecture rule (AGENTS.md section 2): the collector app must never call
| the AI service directly. The Node.js backend is the gateway, and this
| client is the implementation of that gateway's outbound side.
|
| Responsibilities beyond a plain HTTP call:
|   - timeouts, so a hung model cannot hold a request open
|   - a circuit breaker, so a down AI service fails fast instead of piling
|     up 15-second timeouts
|   - translating transport failures into domain errors (504 vs 503)
|   - normalising the FastAPI response into one internal shape, so the rest
|     of the backend does not depend on FastAPI's field naming
|--------------------------------------------------------------------------
*/

const axios = require("axios");

const config = require("../config/env");
const logger = require("../lib/logger");
const {
  UpstreamTimeoutError,
  UpstreamUnavailableError,
  UnprocessableError,
} = require("../lib/errors");

const {
  deployedModel,
  MATERIAL_ID_BY_CLASS,
  CRITICAL_MINERAL_POTENTIAL_MESSAGE,
} = require("../config/constants");

/*
|--------------------------------------------------------------------------
| CIRCUIT BREAKER
|--------------------------------------------------------------------------
| After `threshold` consecutive failures the breaker opens for
| `cooldownMs`. While open, calls are rejected immediately, which protects
| the backend and gives the collector a fast, honest "try again" instead of
| a 15 second stall.
|--------------------------------------------------------------------------
*/

const breaker = {
  state: "CLOSED", // CLOSED | OPEN | HALF_OPEN
  failures: 0,
  openedAt: 0,
};

function breakerIsOpen() {
  if (breaker.state === "CLOSED") {
    return false;
  }

  if (breaker.state === "OPEN") {
    const elapsed = Date.now() - breaker.openedAt;

    if (elapsed >= config.ai.breakerCooldownMs) {
      // Let one probe through to see whether the service has recovered.
      breaker.state = "HALF_OPEN";

      return false;
    }

    return true;
  }

  // HALF_OPEN: allow a single probe.
  return false;
}

function recordSuccess() {
  breaker.state = "CLOSED";
  breaker.failures = 0;
}

function recordFailure() {
  breaker.failures += 1;

  if (breaker.failures >= config.ai.breakerThreshold) {
    breaker.state = "OPEN";
    breaker.openedAt = Date.now();

    logger.warn("AI service circuit breaker opened", {
      failures: breaker.failures,
      cooldownMs: config.ai.breakerCooldownMs,
    });
  }
}

/** Test helper. */
function resetBreaker() {
  breaker.state = "CLOSED";
  breaker.failures = 0;
  breaker.openedAt = 0;
}

function breakerStatus() {
  return {
    state: breaker.state,
    consecutiveFailures: breaker.failures,
  };
}

/*
|--------------------------------------------------------------------------
| HTTP
|--------------------------------------------------------------------------
*/

const http = axios.create({
  baseURL: config.ai.baseUrl,
  timeout: config.ai.timeoutMs,
  // Do not throw on 4xx/5xx: the FastAPI body carries a useful `detail`
  // message that must be forwarded to the client.
  validateStatus: () => true,
  maxBodyLength: config.ai.maxImageBytes * 2,
  maxContentLength: config.ai.maxImageBytes * 2,
});

/**
 * Perform a request to the AI service, applying the breaker and mapping
 * transport errors onto domain errors.
 */
async function call(path, options = {}) {
  if (breakerIsOpen()) {
    throw new UpstreamUnavailableError(
      "AI analysis is temporarily unavailable. Please try again shortly.",
      breakerStatus()
    );
  }

  const startedAt = Date.now();

  try {
    const response = await http.request({ url: path, method: "GET", ...options });

    if (response.status >= 500) {
      recordFailure();

      throw new UpstreamUnavailableError("AI service returned an error", {
        upstreamStatus: response.status,
      });
    }

    recordSuccess();

    return {
      status: response.status,
      data: response.data,
      latencyMs: Date.now() - startedAt,
    };
  } catch (error) {
    // A domain error thrown above is rethrown unchanged.
    if (error.isOperational) {
      throw error;
    }

    recordFailure();

    if (error.code === "ECONNABORTED" || error.code === "ETIMEDOUT") {
      throw new UpstreamTimeoutError("AI service did not respond in time", {
        timeoutMs: config.ai.timeoutMs,
      });
    }

    if (error.response) {
      throw new UpstreamUnavailableError("AI service request failed", {
        upstreamStatus: error.response.status,
      });
    }

    throw new UpstreamUnavailableError(
      "Could not reach the AI service",
      { reason: error.code || error.message }
    );
  }
}

/*
|--------------------------------------------------------------------------
| NORMALISATION
|--------------------------------------------------------------------------
| FastAPI snake_case -> the internal camelCase shape used by the rest of the
| backend. Anything the AI service omits becomes an explicit null rather
| than undefined, so a lot is never persisted with a hole in it.
|--------------------------------------------------------------------------
*/

function normaliseAnalysis(data, latencyMs) {
  const material = data?.material ?? null;
  const confidence =
    typeof data?.confidence === "number" ? data.confidence : null;

  const isLowConfidence =
    confidence !== null && confidence < deployedModel.confidenceThreshold;

  return {
    material,
    // Catalogue id used by material_rates, e.g. "pcb" -> "pcb",
    // "lcd_panel" -> "lcd-panel".
    materialId: material ? (MATERIAL_ID_BY_CLASS[material] ?? null) : null,

    confidence,
    isLowConfidence,

    criticalMineral: Boolean(data?.critical_mineral),
    criticalMineralReason: data?.critical_mineral_reason ?? null,

    // Rule-based inference, so the wording must stay "potential"
    // (AGENTS.md section 7).
    criticalMineralWording: data?.critical_mineral
      ? CRITICAL_MINERAL_POTENTIAL_MESSAGE
      : null,

    modelVersion: data?.model_version ?? null,
    ruleVersion: data?.rule_version ?? null,
    supportedMaterials: Array.isArray(data?.supported_materials)
      ? data.supported_materials
      : [],

    weightEstimate: {
      value: data?.weight_estimate?.value ?? null,
      unit: data?.weight_estimate?.unit ?? "kg",
    },

    valueEstimate: {
      min: data?.value_estimate?.min ?? null,
      max: data?.value_estimate?.max ?? null,
      currency: data?.value_estimate?.currency ?? "INR",
    },

    latencyMs: latencyMs ?? null,
  };
}

/*
|--------------------------------------------------------------------------
| PUBLIC API
|--------------------------------------------------------------------------
*/

/**
 * POST /api/v1/analyze
 *
 * @param {object} params
 * @param {Buffer} params.fileBuffer
 * @param {string} params.filename
 * @param {string} params.mimetype
 * @param {number} [params.weightKg]  Improves the value estimate
 */
async function analyzeMaterial({ fileBuffer, filename, mimetype, weightKg }) {
  // Imported lazily: form-data is only needed on this path, and keeping the
  // require here means the rest of the service does not load it.
  const FormData = require("form-data");

  if (!fileBuffer || fileBuffer.length === 0) {
    throw new UnprocessableError("No image was provided", "NO_IMAGE");
  }

  const form = new FormData();

  form.append("file", fileBuffer, {
    filename: filename || "upload.jpg",
    contentType: mimetype || "image/jpeg",
    knownLength: fileBuffer.length,
  });

  if (typeof weightKg === "number" && Number.isFinite(weightKg) && weightKg > 0) {
    form.append("weight_kg", String(weightKg));
  }

  const result = await call(config.ai.analyzePath, {
    method: "POST",
    headers: form.getHeaders(),
    data: form,
  });

  if (result.status !== 200) {
    // FastAPI reports validation problems in `detail`.
    throw new UnprocessableError(
      result.data?.detail || "AI analysis failed",
      "AI_ANALYSIS_FAILED"
    );
  }

  return normaliseAnalysis(result.data, result.latencyMs);
}

/**
 * POST /api/v1/critical-mineral/check
 * Rule engine only — no image involved.
 */
async function checkCriticalMineral(material) {
  const result = await call(config.ai.criticalMineralPath, {
    method: "POST",
    data: { material },
  });

  if (result.status !== 200) {
    throw new UnprocessableError(
      result.data?.detail || "Critical mineral check failed",
      "CRITICAL_MINERAL_CHECK_FAILED"
    );
  }

  return {
    material: result.data?.material ?? material,
    criticalMineral: Boolean(result.data?.critical_mineral),
    reason: result.data?.critical_mineral_reason ?? null,
    ruleVersion: result.data?.rule_version ?? null,
    wording: result.data?.critical_mineral
      ? CRITICAL_MINERAL_POTENTIAL_MESSAGE
      : null,
  };
}

/**
 * GET /health on the AI service, used by the readiness probe.
 */
async function health() {
  const result = await call(config.ai.healthPath, { method: "GET" });

  return {
    reachable: result.status === 200,
    status: result.status,
    body: result.data,
    latencyMs: result.latencyMs,
    breaker: breakerStatus(),
  };
}

module.exports = {
  analyzeMaterial,
  checkCriticalMineral,
  health,
  breakerStatus,
  resetBreaker,
  normaliseAnalysis,
};
