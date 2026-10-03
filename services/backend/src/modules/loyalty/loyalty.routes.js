const express = require("express");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { userRole } = require("../../config/constants");
const store = require("./loyalty.store");

const router = express.Router();

router.use(requireAuth());

function publicId(req) {
  return req.user?.publicId || req.user?.id;
}

// POST /api/loyalty/chooses — USER records a kabadiwala selection
router.post(
  "/chooses",
  requireRole(userRole.USER),
  asyncHandler(async (req, res) => {
    const collectorId = String(req.body?.collectorId || "").trim();
    if (!collectorId) {
      return sendError(res, 400, { message: "collectorId is required" });
    }
    store.ensureProfile(publicId(req), {
      fullName: req.user.fullName,
      phone: req.user.phone,
    });
    const pair = store.recordChoose(publicId(req), collectorId);
    sendSuccess(res, { data: { pair } });
  })
);

// POST /api/loyalty/purchases — USER (or COLLECTOR mirror) records a completed deal
router.post(
  "/purchases",
  requireRole(userRole.USER, userRole.COLLECTOR),
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const collectorId =
      req.user.role === userRole.COLLECTOR
        ? publicId(req)
        : String(body.collectorId || "").trim();
    const userId =
      req.user.role === userRole.USER
        ? publicId(req)
        : String(body.userId || "").trim();

    if (!collectorId || !userId) {
      return sendError(res, 400, { message: "collectorId and userId are required" });
    }

    if (req.user.role === userRole.USER) {
      store.ensureProfile(userId, {
        fullName: req.user.fullName,
        phone: req.user.phone,
      });
    }

    const result = store.recordPurchase({
      userId,
      collectorId,
      requestId: body.requestId || null,
      amount: Number(body.amount) || 0,
      userName:
        body.userName ||
        (req.user.role === userRole.USER ? req.user.fullName : null),
      userPhone:
        body.userPhone ||
        (req.user.role === userRole.USER ? req.user.phone : null),
    });

    sendSuccess(res, {
      data: {
        pair: result.pair,
        becameRegular: result.becameRegular,
        referralAwarded: result.referralAwarded,
        duplicate: result.duplicate,
        threshold: store.THRESHOLD,
      },
      status: result.duplicate ? 200 : 201,
    });
  })
);

// GET /api/loyalty/me — USER loyalty dashboard
router.get(
  "/me",
  requireRole(userRole.USER),
  asyncHandler(async (req, res) => {
    const data = store.listForUser(publicId(req));
    sendSuccess(res, { data });
  })
);

// GET /api/loyalty/customers — COLLECTOR regular/inactive list
router.get(
  "/customers",
  requireRole(userRole.COLLECTOR),
  asyncHandler(async (req, res) => {
    const customers = store.listCustomersForCollector(publicId(req));
    sendSuccess(res, {
      data: { customers, count: customers.length, threshold: store.THRESHOLD },
    });
  })
);

// POST /api/loyalty/reminders — COLLECTOR sends inactivity reminder
router.post(
  "/reminders",
  requireRole(userRole.COLLECTOR),
  asyncHandler(async (req, res) => {
    const userId = String(req.body?.userId || "").trim();
    const cadence = String(req.body?.cadence || "WEEK").toUpperCase();
    if (!userId) {
      return sendError(res, 400, { message: "userId is required" });
    }
    const result = store.sendReminder({
      collectorId: publicId(req),
      userId,
      cadence,
      collectorName: req.user.fullName || "Kabadiwala",
    });
    if (!result.ok) {
      return sendError(res, result.status || 400, { message: result.error });
    }
    sendSuccess(res, { data: { notification: result.notification }, status: 201 });
  })
);

// POST /api/loyalty/referral/apply
router.post(
  "/referral/apply",
  requireRole(userRole.USER),
  asyncHandler(async (req, res) => {
    store.ensureProfile(publicId(req), {
      fullName: req.user.fullName,
      phone: req.user.phone,
    });
    const result = store.applyReferralCode(publicId(req), req.body?.code);
    if (!result.ok) {
      return sendError(res, 400, { message: result.error });
    }
    sendSuccess(res, { data: result });
  })
);

// GET /api/loyalty/referral
router.get(
  "/referral",
  requireRole(userRole.USER),
  asyncHandler(async (req, res) => {
    const data = store.listForUser(publicId(req));
    const earned = (data.profile.ledger || [])
      .filter((e) => e.reason === "REFERRAL_REWARD")
      .reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
    sendSuccess(res, {
      data: {
        referralCode: data.profile.referralCode,
        creditsBalance: data.profile.creditsBalance,
        referralEarnings: earned,
        referredBy: data.profile.referredBy,
        referralAwarded: data.profile.referralAwarded,
        creditPerSide: store.REFERRAL_CREDIT_INR,
        ledger: data.profile.ledger,
      },
    });
  })
);

// GET /api/loyalty/notifications — in-app loyalty notifications for caller
router.get(
  "/notifications",
  requireRole(userRole.USER, userRole.COLLECTOR),
  asyncHandler(async (req, res) => {
    const list = store.getNotifications(publicId(req));
    sendSuccess(res, {
      data: { notifications: list, count: list.length },
    });
  })
);

// PATCH /api/loyalty/notifications/:id/read
router.patch(
  "/notifications/:id/read",
  requireRole(userRole.USER, userRole.COLLECTOR),
  asyncHandler(async (req, res) => {
    const item = store.markNotificationRead(publicId(req), req.params.id);
    if (!item) {
      return sendError(res, 404, { message: "Notification not found" });
    }
    sendSuccess(res, { data: { notification: item } });
  })
);

router.store = store;
module.exports = router;
