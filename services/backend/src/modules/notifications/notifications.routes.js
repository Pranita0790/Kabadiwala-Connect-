/*
|--------------------------------------------------------------------------
| NOTIFICATIONS CONTROLLER + ROUTES  →  /api/notifications
|--------------------------------------------------------------------------
*/

const express = require("express");

const service = require("./notifications.service");
const schemas = require("./notifications.schema");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { requireAuth } = require("../../middleware/auth");
const { validate, validatedQuery } = require("../../middleware/validate");
const { parsePagination, buildMeta } = require("../../lib/pagination");

const router = express.Router();

/**
 * GET /api/notifications
 *
 * Matches the collector's proposed contract
 * (ApiService.fetchNotifications): a flat list of the caller's notifications.
 */
router.get(
  "/",
  requireAuth(),
  validate(schemas.list),
  asyncHandler(async (req, res) => {
    const query = validatedQuery(req);
    const pagination = parsePagination(query);

    const result = await service.list(req.user.id, {
      limit: pagination.limit,
      offset: pagination.offset,
      unreadOnly: query.unreadOnly || false,
    });

    sendSuccess(res, {
      data: {
        // Flat array as the collector app expects.
        notifications: result.notifications,
        ...buildMeta({ ...pagination, total: result.meta.total }),
        unreadCount: result.meta.unreadCount,
      },
    });
  })
);

// PATCH /api/notifications/:id/read
router.patch(
  "/:id/read",
  requireAuth(),
  validate(schemas.markRead),
  asyncHandler(async (req, res) => {
    const notification = await service.markRead(req.user.id, req.params.id);

    sendSuccess(res, { message: "Notification marked as read", data: { notification } });
  })
);

// PATCH /api/notifications/read-all
router.patch(
  "/read-all",
  requireAuth(),
  asyncHandler(async (req, res) => {
    const result = await service.markAllRead(req.user.id);

    sendSuccess(res, { message: "All notifications marked as read", data: result });
  })
);

module.exports = router;