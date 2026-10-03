/*
|--------------------------------------------------------------------------
| TRACEABILITY ROUTES  →  /api/traceability
|--------------------------------------------------------------------------
| PUBLIC READ, deliberately.
|
| The deployed Recycler Dashboard fetches GET /api/traceability with no
| Authorization header and falls back to localStorage when it fails. The
| modular service was designed ADMIN/RECYCLER-only, but enforcing that now
| would silently break a live integration (AGENTS.md section 5), so the read
| endpoints stay anonymous until the dashboard ships login.
|
| PRIVACY TRADE-OFF (tracked, not forgotten): these records expose the
| collector's full name and collection address. Once the dashboard
| authenticates, this router must move behind requireRole(RECYCLER, ADMIN).
| See docs/api/api-contract.md.
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./traceability.service");
const schemas = require("./traceability.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { validate, validatedQuery } = require("../../middleware/validate");
const { parsePagination, buildMeta } = require("../../lib/pagination");

const router = express.Router();

// GET /api/traceability
router.get(
  "/",
  validate(schemas.list),
  asyncHandler(async (req, res) => {
    const query = validatedQuery(req);
    const pagination = parsePagination(query);

    const { records, total } = await service.list({
      search: query.search || null,
      status: query.status || null,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    const meta = buildMeta({ ...pagination, total });

    sendSuccess(res, {
      data: { records, count: records.length, meta },
      // Top-level aliases for the deployed dashboard.
      extra: { records, count: records.length, meta },
    });
  })
);

// GET /api/traceability/:lotId
router.get(
  "/:lotId",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const record = await service.getByIdentifier(req.params.lotId);

    sendSuccess(res, { data: { record }, extra: { record } });
  })
);

module.exports = router;
