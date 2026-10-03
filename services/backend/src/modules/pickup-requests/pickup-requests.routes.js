const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");

function notifyUserApp(id, status, extras = {}) {
  try {
    // Lazy require avoids circular init issues with user-api ↔ pickup-requests.
    const userApi = require("../user-api/user-api.routes");
    if (typeof userApi.applyCollectorStatus === "function") {
      userApi.applyCollectorStatus(id, status, extras);
    }
  } catch (_) {
    /* user-api may not be loaded in some test contexts */
  }
}

function recordLoyaltyPurchase(request) {
  try {
    const loyalty = require("../loyalty/loyalty.store");
    if (!request?.userId || !request?.collectorId) return;
    loyalty.recordPurchase({
      userId: request.userId,
      collectorId: request.collectorId,
      requestId: request.id,
      amount: Number(request.finalAmount) || 0,
      userName: request.userName || null,
      userPhone: request.userPhone || null,
    });
  } catch (_) {
    /* loyalty module optional in some test contexts */
  }
}

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
      return sendError(res, 404, { message: `Pickup request ${id} not found` });
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
      return sendError(res, 404, { message: `Pickup request ${id} not found` });
    }

    const updated = {
      ...existing,
      status: status || existing.status,
      updatedAt: new Date().toISOString(),
      completedAt: status === "COMPLETED" ? new Date().toISOString() : existing.completedAt,
    };

    pickupRequestsStore.set(id, updated);
    notifyUserApp(id, updated.status);
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
      return sendError(res, 404, { message: `Pickup request ${id} not found` });
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
    notifyUserApp(id, "COMPLETED", {
      actualWeightKg: weight,
      finalAmount,
      paymentMethod: completed.paymentMethod,
      paymentStatus: "PAID",
    });
    recordLoyaltyPurchase(completed);
    sendSuccess(res, { data: { request: completed } });
  })
);

/**
 * Mirror a household-user request into the collector pickup queue.
 * Status REQUEST_CREATED maps to PENDING for Accept / Reject in collector app.
 */
function ingestFromUserApi(userRequest) {
  if (!userRequest || !userRequest.id) return;
  const status =
    userRequest.status === "REQUEST_CREATED" ? "PENDING" : userRequest.status || "PENDING";
  pickupRequestsStore.set(userRequest.id, {
    id: userRequest.id,
    userId: userRequest.userId || "cust_demo",
    userName: userRequest.userName || "Customer",
    userPhone: userRequest.userPhone || "",
    pickupAddress: userRequest.pickupAddress || "",
    latitude: userRequest.latitude || 18.5204,
    longitude: userRequest.longitude || 73.8567,
    preferredTimeSlot: userRequest.preferredTimeSlot || "Flexible",
    materialCategory: userRequest.materialCategory || "General",
    materialName: userRequest.materialName || "Scrap",
    estimatedWeightKg: Number(userRequest.estimatedWeightKg) || 0,
    ratePerKg: Number(userRequest.ratePerKg) || 0,
    description: userRequest.description || "",
    status,
    paymentStatus: userRequest.paymentStatus || "PENDING",
    collectorId: userRequest.collectorId || "default_collector",
    createdAt: userRequest.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
}

router.ingestFromUserApi = ingestFromUserApi;
module.exports = router;
