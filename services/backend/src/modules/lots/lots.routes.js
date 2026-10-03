/*
|--------------------------------------------------------------------------
| LOTS ROUTES  →  /api/lots
|--------------------------------------------------------------------------
| The lot is the central traceability record. Every route here is
| authenticated: a lot carries a collector's name, address and earnings, so it
| is never public.
|
| Response shapes:
|   GET  /api/lots              -> { success, lots[], count, data, meta }
|        `lots` is kept top-level because the deployed collector expects it.
|   POST /api/lots              -> { success, lot, created, warnings }
|   GET/PATCH/DELETE /:id       -> { success, lot }
|   PATCH /:id/status           -> { success, lot, changed }
|   POST /api/lots/sync         -> { success, result }
|   GET  /:id/analyses          -> { success, analyses, count }
|   POST /:id/analysis          -> { success, lot, warnings }
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./lots.service");
const schemas = require("./lots.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendResource } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { validate, validatedQuery } = require("../../middleware/validate");
const { parsePagination, buildMeta } = require("../../lib/pagination");
const {
  userRole,
  toCanonicalLotStatus,
} = require("../../config/constants");
const { ValidationError } = require("../../lib/errors");

const router = express.Router();

router.use(requireAuth());

/*
|--------------------------------------------------------------------------
| OFFLINE SYNC
|--------------------------------------------------------------------------
| Declared before /:id so "sync" is not mistaken for a lot identifier.
|--------------------------------------------------------------------------
*/

// POST /api/lots/sync
router.post(
  "/sync",
  requireRole(userRole.COLLECTOR, userRole.ADMIN),
  validate(schemas.sync),
  asyncHandler(async (req, res) => {
    const { items, conflictStrategy } = req.body;

    const result = await service.syncBatch(items, req.user, { conflictStrategy });

    sendSuccess(res, {
      data: { result },
      extra: { result },
    });
  })
);

/*
|--------------------------------------------------------------------------
| COLLECTION
|--------------------------------------------------------------------------
*/

// POST /api/lots
router.post(
  "/",
  requireRole(userRole.COLLECTOR, userRole.ADMIN),
  validate(schemas.create),
  asyncHandler(async (req, res) => {
    const { lot, created, warnings } = await service.create(req.body, req.user);

    sendSuccess(res, {
      status: created ? 201 : 200,
      data: { lot, created, warnings },
      extra: { lot, created, warnings },
    });
  })
);

// GET /api/lots
router.get(
  "/",
  validate(schemas.list),
  asyncHandler(async (req, res) => {
    const query = validatedQuery(req);
    const pagination = parsePagination(query);

    const { lots, total } = await service.list(
      {
        status: query.status ? toCanonicalLotStatus(query.status) : undefined,
        materialId: query.materialId,
        criticalOnly: query.criticalOnly === "true",
        search: query.search,
        since: query.since,
      },
      req.user
    );

    sendSuccess(res, {
      data: { lots, count: lots.length, meta: buildMeta({ ...pagination, total }) },
      // Top-level aliases for the deployed collector.
      extra: {
        lots,
        count: lots.length,
        meta: buildMeta({ ...pagination, total }),
      },
    });
  })
);

// GET /api/lots/:id
router.get(
  "/:id",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const lot = await service.getByIdentifier(req.params.id, req.user);

    sendResource(res, "lot", lot, { extra: { lot } });
  })
);

// PATCH /api/lots/:id
router.patch(
  "/:id",
  validate(schemas.update),
  asyncHandler(async (req, res) => {
    const { version, ...patch } = req.body;

    const lot = await service.update(req.params.id, patch, req.user, {
      expectedVersion: version ?? null,
    });

    sendResource(res, "lot", lot, { extra: { lot } });
  })
);

// PATCH /api/lots/:id/status
router.patch(
  "/:id/status",
  validate(schemas.changeStatus),
  asyncHandler(async (req, res) => {
    const canonical = toCanonicalLotStatus(req.body.status);

    if (!canonical) {
      throw new ValidationError(
        `Unknown lot status "${req.body.status}".`,
        { allowedStatuses: ["Pending", "Accepted", "Rejected", "Handover", "Completed"] }
      );
    }

    const { lot, changed } = await service.changeStatus(
      req.params.id,
      canonical,
      req.user,
      { note: req.body.note }
    );

    sendSuccess(res, { data: { lot, changed }, extra: { lot, changed } });
  })
);

// DELETE /api/lots/:id  — soft delete, keeps the audit trail
router.delete(
  "/:id",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const result = await service.remove(req.params.id, req.user);

    sendSuccess(res, { message: "Lot withdrawn", data: result });
  })
);

/*
|--------------------------------------------------------------------------
| AI ANALYSES
|--------------------------------------------------------------------------
*/

// GET /api/lots/:id/analyses
router.get(
  "/:id/analyses",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const analyses = await service.getAnalyses(req.params.id, req.user);

    sendSuccess(res, { data: { analyses, count: analyses.length } });
  })
);

// POST /api/lots/:id/analysis
router.post(
  "/:id/analysis",
  validate(schemas.attachAnalysis),
  asyncHandler(async (req, res) => {
    const { lot, warnings } = await service.attachAnalysis(
      req.params.id,
      req.body,
      req.user
    );

    sendSuccess(res, { data: { lot, warnings }, extra: { lot, warnings } });
  })
);

module.exports = router;
