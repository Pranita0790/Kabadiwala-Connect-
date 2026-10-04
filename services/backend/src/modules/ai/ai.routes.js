/*
|--------------------------------------------------------------------------
| AI ROUTES  →  /api/ai
|--------------------------------------------------------------------------
| POST /api/ai/analyze — the collector app's only route to material
| classification. It is deliberately NOT behind requireDatabase(): the
| response needs no database, and the gateway must keep classifying even
| while persistence is unavailable.
|
| A token is accepted but not required (optionalAuth): the endpoint existed
| before authentication did, and the deployed APK calls it anonymously.
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./ai.service");
const schemas = require("./ai.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendError } = require("../../lib/response");
const { optionalAuth } = require("../../middleware/auth");
const { aiAnalyzeLimiter } = require("../../middleware/rate-limit");
const { singleImage, handleUploadErrors } = require("../../middleware/upload");
const { validate } = require("../../middleware/validate");

const router = express.Router();

/*
| Express 5 leaves req.body undefined when no body parser claimed the
| request (e.g. a request with no file and no Content-Type). The analyze
| schema treats those fields as optional, so normalise undefined to {} before
| validation instead of rejecting an empty request for the wrong reason.
*/
function ensureBody(req, res, next) {
  if (req.body === undefined || req.body === null) {
    req.body = {};
  }

  next();
}

// POST /api/ai/analyze
router.post(
  "/analyze",
  aiAnalyzeLimiter,
  optionalAuth(),
  singleImage,
  handleUploadErrors,
  ensureBody,
  validate(schemas.analyze),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      // Same message and status the previous gateway returned, so the
      // deployed collector's error handling keeps working.
      return sendError(res, 400, {
        code: "NO_IMAGE",
        message: "No image file provided.",
      });
    }

    const { weight_kg: weightKgSnake, weightKg, lot_id: lotIdSnake, lotId } =
      req.body;

    const result = await service.analyze({
      file: req.file,
      weightKg: weightKg ?? weightKgSnake,
      lotId: lotId ?? lotIdSnake ?? null,
      user: req.user,
    });

    // RAW FastAPI body: the frozen response shape (AGENTS.md section 5).
    return res.status(200).json(result.analysis);
  })
);

// POST /api/ai/copilot — Multimodal & Multilingual AI Voice/Image Copilot
router.post(
  "/copilot",
  optionalAuth(),
  asyncHandler(async (req, res) => {
    const { message, language, imageBase64, mimetype, context } = req.body || {};
    const gemini = require("../../clients/gemini.client");
    const result = await gemini.chatWithAssistant({
      message: message || "Analyze scrap and suggest best rate and recycler",
      language: language || "hi",
      imageBase64: imageBase64 || null,
      mimetype: mimetype || "image/jpeg",
      context: context || {},
    });
    return res.status(200).json({ success: true, data: result });
  })
);

// POST /api/ai/recycler-audit — AI Lot Purity, Minerals & EPR Audit for Recyclers
router.post(
  "/recycler-audit",
  optionalAuth(),
  asyncHandler(async (req, res) => {
    const gemini = require("../../clients/gemini.client");
    const audit = await gemini.generateRecyclerLotAudit({
      lotData: req.body || {},
    });
    return res.status(200).json({ success: true, data: audit });
  })
);

// GET /api/ai/rates-index — AI Market Rates & Critical Mineral breakdown
router.get(
  "/rates-index",
  asyncHandler(async (req, res) => {
    const gemini = require("../../clients/gemini.client");
    return res.status(200).json({
      success: true,
      data: {
        rates: gemini.ESTIMATED_RATES,
        critical_minerals: gemini.MINERAL_MAP,
        timestamp: new Date().toISOString(),
      },
    });
  })
);

module.exports = router;
