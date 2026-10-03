/*
|--------------------------------------------------------------------------
| MATERIALS ROUTES  →  /api/materials
|--------------------------------------------------------------------------
| Public reference data: clients need valid material ids to build lot
| creation and recycler-filter UI before authentication.
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./materials.service");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { validatedQuery } = require("../../middleware/validate");

const router = express.Router();

// GET /api/materials
router.get(
  "/",
  asyncHandler(async (req, res) => {
    const { modelSupported } = validatedQuery(req);
    const materials = await service.list({
      modelSupportedOnly: modelSupported === "true",
    });

    sendSuccess(res, {
      data: { materials, count: materials.length },
      extra: { materials },
    });
  })
);

// GET /api/materials/capabilities — what the deployed model supports
router.get(
  "/capabilities",
  asyncHandler(async (req, res) => {
    sendSuccess(res, { data: await service.modelCapabilities() });
  })
);

// GET /api/materials/:id
router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const material = await service.get(req.params.id);

    sendSuccess(res, { data: { material } });
  })
);

module.exports = router;