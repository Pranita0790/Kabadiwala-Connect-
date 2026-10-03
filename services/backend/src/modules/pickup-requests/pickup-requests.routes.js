const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");

// In-memory / DB fallback store for pickup requests
const pickupRequestsStore = new Map();

// Seed initial mock data into backend memory store if empty
const seedPickupRequests = () => {
  if (pickupRequestsStore.size === 0) {
    const demoReqs = [
      {
        id: "req_101",
        userId: "cust_1",
        userName: "Aniket Sharma",
        userPhone: "+91 98234 56789",
        pickupAddress: "Flat 402, Green Valley Apts, Kothrud, Pune",
        latitude: 18.5074,
        longitude: 73.8077,
        preferredTimeSlot: "Today, 4:00 PM - 6:00 PM",
        materialCategory: "E-Waste",
        materialName: "Motherboards & Circuit Boards",
        estimatedWeightKg: 5.0,
        ratePerKg: 120.0,
        description: "Old CPU circuit boards and desktop power supplies.",
        status: "PENDING",
        paymentStatus: "PENDING",
        collectorId: "default_collector",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: "req_102",
        userId: "cust_2",
        userName: "Priya Deshmukh",
        userPhone: "+91 98112 34567",
        pickupAddress: "Plot 12, Baner Pashan Link Rd, Pune",
        latitude: 18.5590,
        longitude: 73.7868,
        preferredTimeSlot: "Tomorrow, 10:00 AM - 12:00 PM",
        materialCategory: "Metals",
        materialName: "Copper Wire & Heavy Metals",
        estimatedWeightKg: 8.0,
        ratePerKg: 450.0,
        description: "Stripped copper wire bundle from electrical renovation.",
        status: "ACCEPTED",
        paymentStatus: "PENDING",
        collectorId: "default_collector",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];
    for (const r of demoReqs) {
      pickupRequestsStore.set(r.id, r);
    }
  }
};

seedPickupRequests();

// GET /api/pickup-requests
router.get(
  "/",
  asyncHandler(async (req, res) => {
    const { status } = req.query;
    let list = Array.from(pickupRequestsStore.values());
    if (status) {
      list = list.filter((r) => r.status === status);
    }
    sendSuccess(res, {
      data: { requests: list, count: list.length },
    });
  })
);

// POST /api/pickup-requests
router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const request = pickupRequestsStore.get(id);
    if (!request) {
      return sendError(res, { status: 404, message: `Pickup request ${id} not found` });
    }
    sendSuccess(res, { data: { request } });
  })
);

// POST /api/pickup-requests (create user request)
router.post(
  "/",
  asyncHandler(async (req, res) => {
    const body = req.body;
    const id = body.id || `req_${Date.now()}`;
    const newRequest = {
      id,
      userId: body.userId || "cust_demo",
      userName: body.userName || "Customer",
      userPhone: body.userPhone || "",
      pickupAddress: body.pickupAddress || "",
      latitude: body.latitude || 18.5204,
      longitude: body.longitude || 73.8567,
      preferredTimeSlot: body.preferredTimeSlot || "Flexible",
      materialCategory: body.materialCategory || "General",
      materialName: body.materialName || "Scrap",
      estimatedWeightKg: Number(body.estimatedWeightKg) || 0,
      ratePerKg: Number(body.ratePerKg) || 0, // Snapshot rate
      description: body.description || "",
      status: "PENDING",
      paymentStatus: "PENDING",
      collectorId: body.collectorId || "default_collector",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    pickupRequestsStore.set(id, newRequest);
    sendSuccess(res, { data: { request: newRequest }, status: 201 });
  })
);

// PATCH /api/pickup-requests/:id/status
router.patch(
  "/:id/status",
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { status } = req.body;
    const existing = pickupRequestsStore.get(id);
    if (!existing) {
      return sendError(res, { status: 404, message: `Pickup request ${id} not found` });
    }

    const updated = {
      ...existing,
      status: status || existing.status,
      updatedAt: new Date().toISOString(),
      completedAt: status === "COMPLETED" ? new Date().toISOString() : existing.completedAt,
    };

    pickupRequestsStore.set(id, updated);
    sendSuccess(res, { data: { request: updated } });
  })
);

// POST /api/pickup-requests/:id/complete
router.post(
  "/:id/complete",
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { actualWeightKg, paymentMethod } = req.body;
    const existing = pickupRequestsStore.get(id);
    if (!existing) {
      return sendError(res, { status: 404, message: `Pickup request ${id} not found` });
    }

    const weight = Number(actualWeightKg) || existing.estimatedWeightKg;
    const finalAmount = weight * existing.ratePerKg;

    const completed = {
      ...existing,
      actualWeightKg: weight,
      finalAmount,
      paymentMethod: paymentMethod || "CASH",
      paymentStatus: "PAID",
      status: "COMPLETED",
      updatedAt: new Date().toISOString(),
      completedAt: new Date().toISOString(),
    };

    pickupRequestsStore.set(id, completed);
    sendSuccess(res, { data: { request: completed } });
  })
);

module.exports = router;
