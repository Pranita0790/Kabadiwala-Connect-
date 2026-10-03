const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");

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

// GET /api/collector-rates
router.get(
  "/",
  asyncHandler(async (req, res) => {
    const rates = Array.from(collectorRatesStore.values()).filter((r) => r.isActive);
    sendSuccess(res, {
      data: { rates, count: rates.length },
    });
  })
);

// POST /api/collector-rates
router.post(
  "/",
  asyncHandler(async (req, res) => {
    const body = req.body;
    const id = body.id || `rate_${Date.now()}`;
    const rate = {
      id,
      collectorId: body.collectorId || "default_collector",
      materialCategory: body.materialCategory || "General",
      materialName: body.materialName || "Scrap",
      ratePerKg: Number(body.ratePerKg) || 0,
      unit: body.unit || "kg",
      isActive: body.isActive !== false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    collectorRatesStore.set(id, rate);
    sendSuccess(res, { data: { rate }, status: 201 });
  })
);

// DELETE /api/collector-rates/:id
router.delete(
  "/:id",
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    if (!collectorRatesStore.has(id)) {
      return sendError(res, { status: 404, message: `Collector rate ${id} not found` });
    }
    const existing = collectorRatesStore.get(id);
    collectorRatesStore.set(id, { ...existing, isActive: false });
    sendSuccess(res, { message: `Rate ${id} deleted` });
  })
);

module.exports = router;
