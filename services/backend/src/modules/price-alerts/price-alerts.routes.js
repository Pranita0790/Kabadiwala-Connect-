/*
|--------------------------------------------------------------------------
| PRICE ALERTS CONTROLLER + ROUTES  →  /api/price-alerts
|--------------------------------------------------------------------------
| Matches the collector's proposed contract:
|   POST /api/price-alerts   (ApiService.uploadPriceAlert)
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./price-alerts.service");
const schemas = require("./price-alerts.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { validate, validatedQuery } = require("../../middleware/validate");
const { parsePagination, buildMeta } = require("../../lib/pagination");
const { userRole } = require("../../config/constants");

const router = express.Router();

router.use(requireAuth(), requireRole(userRole.COLLECTOR));

// POST /api/price-alerts
router.post(
  "/",
  validate(schemas.create),
  asyncHandler(async (req, res) => {
    const alert = await service.create(req.user.id, req.body);

    sendSuccess(res, { status: 201, message: "Price alert created", data: { alert } });
  })
);

// GET /api/price-alerts
router.get(
  "/",
  validate(schemas.list),
  asyncHandler(async (req, res) => {
    const query = validatedQuery(req);
    const pagination = parsePagination(query);

    const { alerts, total } = await service.list(req.user.id, {
      limit: pagination.limit,
      offset: pagination.offset,
      activeOnly: query.activeOnly || false,
    });

    sendSuccess(res, {
      data: {
        alerts,
        ...buildMeta({ ...pagination, total }),
      },
    });
  })
);

// DELETE /api/price-alerts/:id
router.delete(
  "/:id",
  validate(schemas.byId),
  asyncHandler(async (req, res) => {
    const alert = await service.remove(req.user.id, req.params.id);

    sendSuccess(res, { message: "Price alert removed", data: { alert } });
  })
);

module.exports = router;