const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");
const { optionalAuth } = require("../../middleware/auth");

const collectorRatesStore = new Map();

const seedCollectorRates = () => {
  if (collectorRatesStore.size === 0) {
    const demoRates = [
      {
        id: "rate_1",
        collectorId: "default_collector",
        materialCategory: "E-Waste",
        materialName: "Motherboards & Circuit Boards",
        ratePerKg: 120.0,
        unit: "kg",
        isActive: true,
        createdAt: new Date().toISOString(),
      },
      {
        id: "rate_2",
        collectorId: "default_collector",
        materialCategory: "Metals",
        materialName: "Copper Wire & Scrap",
        ratePerKg: 450.0,
        unit: "kg",
        isActive: true,
        createdAt: new Date().toISOString(),
      },
    ];
    for (const r of demoRates) {
      collectorRatesStore.set(r.id, r);
    }
  }
};

seedCollectorRates();

function resolveCollectorId(req, bodyCollectorId) {
  const fromAuth = req.user?.publicId;
  if (fromAuth) return String(fromAuth);
  if (bodyCollectorId && String(bodyCollectorId).trim()) {
    return String(bodyCollectorId).trim();
  }
  return "default_collector";
}

// GET /api/collector-rates
// Optional ?collectorId= to return one kabadiwala's rate card.
router.get(
  "/",
  optionalAuth(),
  asyncHandler(async (req, res) => {
    const filterId =
      (req.query.collectorId && String(req.query.collectorId).trim()) ||
      (req.user?.role === "COLLECTOR" ? req.user.publicId : null);

    let rates = Array.from(collectorRatesStore.values()).filter((r) => r.isActive);
    if (filterId) {
      const own = rates.filter((r) => r.collectorId === filterId);
      rates = own.length > 0 ? own : rates.filter((r) => r.collectorId === "default_collector");
    }

    sendSuccess(res, {
      data: { rates, count: rates.length },
    });
  })
);

// POST /api/collector-rates
// When a collector JWT is present, rates are bound to that publicId so the
// user app can show them on the nearby kabadiwala list.
router.post(
  "/",
  optionalAuth(),
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const id = body.id || `rate_${Date.now()}`;
    const collectorId = resolveCollectorId(req, body.collectorId);
    const rate = {
      id,
      collectorId,
      collectorName: req.user?.fullName || body.collectorName || null,
      collectorPhone: req.user?.phone || body.collectorPhone || null,
      materialCategory: body.materialCategory || "General",
      materialName: body.materialName || "Scrap",
      ratePerKg: Number(body.ratePerKg) || 0,
      unit: body.unit || "kg",
      isActive: body.isActive !== false,
      createdAt: body.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    collectorRatesStore.set(id, rate);
    sendSuccess(res, { data: { rate }, status: 201 });
  })
);

// DELETE /api/collector-rates/:id
router.delete(
  "/:id",
  optionalAuth(),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    if (!collectorRatesStore.has(id)) {
      return sendError(res, 404, { message: `Collector rate ${id} not found` });
    }
    const existing = collectorRatesStore.get(id);
    if (
      req.user?.role === "COLLECTOR" &&
      existing.collectorId &&
      existing.collectorId !== "default_collector" &&
      existing.collectorId !== req.user.publicId
    ) {
      return sendError(res, 403, { message: "Cannot delete another collector's rate" });
    }
    collectorRatesStore.set(id, { ...existing, isActive: false, updatedAt: new Date().toISOString() });
    sendSuccess(res, { message: `Rate ${id} deleted` });
  })
);

router.ratesStore = collectorRatesStore;
module.exports = router;
