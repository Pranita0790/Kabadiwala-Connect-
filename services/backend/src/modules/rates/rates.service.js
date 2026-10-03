/*
|--------------------------------------------------------------------------
| RATES SERVICE
|--------------------------------------------------------------------------
| Price discovery: the current rate card, rate updates with an audit trail,
| and the indicative value calculation used when a lot is created or
| re-estimated.
|
| Value semantics (important):
| The result is an INDICATIVE ESTIMATE for workflow support, not a market
| transaction price. It is derived from a rule-based rate for the material
| category and the recorded weight. It carries no sampling, assay or purity
| adjustment, and the wording returned to clients says so.
|--------------------------------------------------------------------------
*/

const repository = require("./rates.repository");
const priceAlertsRepository = require("../price-alerts/price-alerts.repository");
const notificationService = require("../notifications/notifications.service");
const logger = require("../../lib/logger");
const { NotFoundError, ValidationError } = require("../../lib/errors");
const { AI_DISCLAIMER } = require("../../config/constants");

const DEFAULT_REGION = "IN-MH";

/** Uncertainty band applied around a category-level rate. */
const VALUE_SPREAD = 0.08;

/*
|--------------------------------------------------------------------------
| LIST / READ
|--------------------------------------------------------------------------
*/

async function listRates({ region = DEFAULT_REGION } = {}) {
  const rates = await repository.listCurrent({ region });

  return rates;
}

async function getRate(publicId, { region = DEFAULT_REGION } = {}) {
  const rate = await repository.findCurrentByPublicId(publicId, { region });

  if (!rate) {
    throw new NotFoundError(`No current rate found for "${publicId}"`, {
      rateId: publicId,
      region,
    });
  }

  return rate;
}

async function getHistory(publicId, { region = DEFAULT_REGION } = {}) {
  // Confirm the rate exists before returning a history, so an unknown id
  // gives 404 rather than an empty list.
  await getRate(publicId, { region });

  return repository.history(publicId);
}

/*
|--------------------------------------------------------------------------
| UPDATE
|--------------------------------------------------------------------------
*/

/**
 * Update the current rate for a material.
 *
 * @param {object} params
 * @param {string} params.publicId     Rate id, e.g. "pcb"
 * @param {number} params.ratePerKg
 * @param {string} [params.actorId]    Internal user id of whoever made the
 *                                      change, recorded on the new rate row
 * @param {string} [params.source]     Free-text provenance, e.g. "MARKET_SURVEY"
 */
async function updateRate({ publicId, ratePerKg, actorId = null, source }) {
  const existing = await getRate(publicId);

  const updated = await repository.updateRate(publicId, {
    ratePerKg,
    source: source || "MANUAL",
    createdBy: actorId,
  });

  if (!updated) {
    throw new NotFoundError(`No current rate found for "${publicId}"`);
  }

  logger.info("Rate updated", {
    rateId: publicId,
    previousRate: existing.ratePerKg,
    newRate: updated.ratePerKg,
    actorId,
  });

  // A rate change is exactly what a price alert exists to detect, so fire
  // any that now match.
  const triggered = await evaluatePriceAlerts({
    materialId: existing.materialId,
    region: existing.region,
    ratePerKg: updated.ratePerKg,
  });

  return { rate: updated, priceAlertsTriggered: triggered };
}

/*
|--------------------------------------------------------------------------
| INDICATIVE VALUE
|--------------------------------------------------------------------------
*/

/**
 * Calculate an indicative value for a quantity of material.
 *
 * @param {object} params
 * @param {string} params.materialId  Catalogue id, e.g. "pcb"
 * @param {number} params.weightKg
 * @param {string} [params.region]
 * @param {Date}   [params.at]        Rate to use; defaults to the current one
 * @returns {object} Indicative value with the wording clients must display
 */
async function calculateIndicativeValue({ materialId, weightKg, region, at }) {
  if (
    typeof weightKg !== "number" ||
    !Number.isFinite(weightKg) ||
    weightKg <= 0
  ) {
    throw new ValidationError("weightKg must be a positive number");
  }

  const rate = await repository.findRateAt(materialId, at || new Date(), {
    region: region || DEFAULT_REGION,
  });

  if (!rate) {
    // No rate means no estimate. Returning null rather than zero keeps "we
    // could not value this" distinguishable from "this material is worth
    // nothing" — which is how the dashboard renders it.
    return {
      materialId,
      weightKg,
      estimatedValue: null,
      estimatedMinValue: null,
      estimatedMaxValue: null,
      currency: "INR",
      ratePerKg: null,
      disclaimer: AI_DISCLAIMER,
      reason: "NO_RATE_FOR_MATERIAL",
    };
  }

  const estimated = Number((rate.ratePerKg * weightKg).toFixed(2));

  // A +/-8% band reflects the uncertainty in a category-level rate applied to
  // an unsampled, unassayed quantity.
  const min = Number((estimated * (1 - VALUE_SPREAD)).toFixed(2));
  const max = Number((estimated * (1 + VALUE_SPREAD)).toFixed(2));

  return {
    materialId,
    weightKg,
    estimatedValue: estimated,
    estimatedMinValue: min,
    estimatedMaxValue: max,
    currency: "INR",
    ratePerKg: rate.ratePerKg,
    rateId: rate.id,
    rateUpdatedAt: rate.updatedAt,
    disclaimer: AI_DISCLAIMER,
  };
}

/*
|--------------------------------------------------------------------------
| PRICE ALERT EVALUATION
|--------------------------------------------------------------------------
*/

/**
 * Trigger any active price alert that the new rate satisfies, and notify the
 * collector. Each alert fires at most once (`triggered_at`).
 */
async function evaluatePriceAlerts({ materialId, region, ratePerKg }) {
  const candidates = await priceAlertsRepository.findMatching(
    { materialId, region, ratePerKg }
  );

  if (candidates.length === 0) {
    return 0;
  }

  const marked = await priceAlertsRepository.markTriggered(
    candidates.map((alert) => alert.id)
  );

  if (marked.length === 0) {
    return 0;
  }

  // markTriggered returns DTOs, so these are camelCase.
  await notificationService.createMany(
    marked.map((alert) => ({
      userId: alert.userId,
      type: "PRICE_ALERT",
      titleEn:
        alert.direction === "ABOVE"
          ? `Price alert: ${alert.materialId} reached ₹${ratePerKg}/kg`
          : `Price alert: ${alert.materialId} fell to ₹${ratePerKg}/kg`,
      bodyEn:
        `Your alert of ₹${alert.targetRatePerKg}/kg ` +
        `(${alert.direction.toLowerCase()}) was met. ` +
        "This is an indicative rate, not a guaranteed offer.",
    }))
  );

  logger.info("Price alerts triggered", {
    materialId,
    region,
    ratePerKg,
    count: marked.length,
  });

  return marked.length;
}

module.exports = {
  listRates,
  getRate,
  getHistory,
  updateRate,
  calculateIndicativeValue,
  evaluatePriceAlerts,
  DEFAULT_REGION,
};