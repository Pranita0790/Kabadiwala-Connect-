/*
|--------------------------------------------------------------------------
| RATES ROUTES  →  /api/rates
|--------------------------------------------------------------------------
| RESPONSE SHAPE IS FROZEN BY DEPLOYED CONSUMERS — do not change without a
| coordinated contract change (AGENTS.md section 5).
|
|   GET /api/rates      ->  { success, rates[], count }
|        The Recycler Dashboard reads `data.rates` (RateBoard.tsx). It also
|        accepts a bare array; the envelope below is the chosen form.
|
|   GET /api/rates/:id  ->  { success, rate }
|
|   PUT /api/rates/:id  ->  BARE rate object, not an envelope.
|        RateBoard.tsx does `setRates(items => items.map(i =>
|        i.id === rate.id ? updatedRate : i))` using the whole response body,
|        so wrapping it in `{ success, data }` would store a wrapper object
|        as a rate row and break the board's edit flow.
|
| GET /api/prices is the collector-facing alias of GET /api/rates, matching
| the collector's proposed ApiService.fetchMarketPrices contract.
|--------------------------------------------------------------------------*/

const express = require("express");

const service = require("./rates.service");
const schemas = require("./rates.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendResource, sendBare } = require("../../lib/response");
const { requireAuth, optionalAuth } = require("../../middleware/auth");
const { validate, validatedQuery } = require("../../middleware/validate");

const router = express.Router();

/*
|--------------------------------------------------------------------------
| READ — public
|--------------------------------------------------------------------------
| The rate board is public market information; the collector app shows it on
| the prices screen before a user has finished signing up.
|--------------------------------------------------------------------------
*/

// GET /api/rates
router.get(
  "/",
  asyncHandler(async (req, res) => {
    const { region } = validatedQuery(req);
    const rates = await service.listRates({ region });

    sendSuccess(res, {
      data: { rates, count: rates.length },
      // Preserve the top-level `rates` key the dashboard reads.
      extra: { rates, count: rates.length },
    });
  })
);

// GET /api/rates/:id
router.get(
  "/:id",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const rate = await service.getRate(req.params.id, {
      region: validatedQuery(req).region,
    });

    sendResource(res, "rate", rate);
  })
);

// GET /api/rates/:id/history — why a settled amount was calculated
router.get(
  "/:id/history",
  requireAuth(),
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const history = await service.getHistory(req.params.id, {
      region: validatedQuery(req).region,
    });

    sendSuccess(res, { data: { history, count: history.length } });
  })
);

/*
|--------------------------------------------------------------------------
| WRITE
|--------------------------------------------------------------------------
| Publishing a rate is a market claim, so once the dashboard authenticates
| this must be restricted to a recycler or admin (requireRole).
|--------------------------------------------------------------------------
|
| PUT /api/rates/:id
|
| PUBLIC, for now, and on purpose. The deployed Recycler Dashboard edits the
| rate board with a PUT that carries no Authorization header; requiring a
| token here would return 401 and break the live board (AGENTS.md section 5).
| The alternative — a dashboard release that logs in first — is the correct
| end state, at which point this becomes requireRole(RECYCLER, ADMIN).
|
| optionalAuth is kept so that, when a caller DOES send a token, the rate
| change is attributed to them in the audit trail instead of to null.
|--------------------------------------------------------------------------*/
router.put(
  "/:id",
  optionalAuth(),
  validate(schemas.byId),
  validate(schemas.updateRate),
  asyncHandler(async (req, res) => {
    const { ratePerKg, source } = req.body;

    const { rate, priceAlertsTriggered } = await service.updateRate({
      publicId: req.params.id,
      ratePerKg,
      actorId: req.user?.id ?? null,
      source,
    });

    // The alert count rides in a header so the bare rate body stays intact
    // for the deployed dashboard.
    res.setHeader("X-Price-Alerts-Triggered", priceAlertsTriggered);

    // BARE response, per the deployed dashboard contract.
    return sendBare(res, rate);
  })
);

module.exports = router;