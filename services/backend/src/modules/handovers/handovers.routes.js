/*
|--------------------------------------------------------------------------
| HANDOVERS ROUTES  →  /api/handovers
|--------------------------------------------------------------------------
*/

const express = require("express");
const { z } = require("zod");

const service = require("./handovers.service");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { validate } = require("../../middleware/validate");
const { userRole } = require("../../config/constants");

const router = express.Router();

router.use(requireAuth());

const createSchema = {
  body: z
    .object({
      id: z.string().trim().max(64).optional(),
      clientReference: z.string().uuid().optional(),
      lotId: z.string().trim().min(1).max(64).optional(),
      lot_id: z.string().trim().min(1).max(64).optional(),
      recyclerId: z.string().trim().max(64).optional(),
      recycler_id: z.string().trim().max(64).optional(),
      recyclerName: z.string().trim().max(120).optional(),
      recycler_name: z.string().trim().max(120).optional(),
      materialCategory: z.string().trim().max(120).optional(),
      material_category: z.string().trim().max(120).optional(),
      weightKg: z.number().nonnegative().finite().optional(),
      weight_kg: z.number().nonnegative().finite().optional(),
      agreedAmount: z.number().nonnegative().finite().optional(),
      agreed_amount: z.number().nonnegative().finite().optional(),
      qrPayload: z.string().trim().max(2000).optional(),
      qr_payload: z.string().trim().max(2000).optional(),
      status: z.string().trim().max(64).optional(),
    })
    .strip(),
};

const byIdSchema = {
  params: z.object({
    id: z.string().trim().min(1).max(64),
  }),
  body: z
    .object({
      // Collector demo / offline confirm: stamp both parties so earnings post.
      completeBoth: z.boolean().optional(),
      demoComplete: z.boolean().optional(),
      paymentMethod: z.enum(["CASH", "UPI"]).optional(),
      finalAmount: z.number().nonnegative().finite().optional(),
    })
    .strip()
    .optional()
    .default({}),
};

// POST /api/handovers
router.post(
  "/",
  requireRole(userRole.COLLECTOR, userRole.RECYCLER, userRole.ADMIN),
  validate(createSchema),
  asyncHandler(async (req, res) => {
    const { handover, created } = await service.create(req.body, req.user);

    sendSuccess(res, {
      status: created ? 201 : 200,
      data: { handover, created },
      extra: { handover, created },
    });
  })
);

// POST /api/handovers/:id/confirm
router.post(
  "/:id/confirm",
  requireRole(userRole.COLLECTOR, userRole.RECYCLER, userRole.ADMIN),
  validate(byIdSchema),
  asyncHandler(async (req, res) => {
    const handover = await service.confirm(req.params.id, req.user, req.body || {});

    sendSuccess(res, {
      message: "Handover confirmation recorded",
      data: { handover },
      extra: { handover },
    });
  })
);

module.exports = router;
