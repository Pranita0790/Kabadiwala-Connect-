const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { userRole } = require("../../config/constants");
const { queryRows } = require("../../db/query");
const config = require("../../config/env");
const pickupRequestsRoutes = require("../pickup-requests/pickup-requests.routes");
const collectorRatesRoutes = require("../collector-rates/collector-rates.routes");

// One login system: household user JWT required for /api/user/*
router.use(requireAuth(), requireRole(userRole.USER));

const MATERIAL_CATEGORIES = ["Paper", "Metal", "Plastic", "E-waste", "Other"];

const DEFAULT_RATES = {
  Paper: 14.0,
  Metal: 42.0,
  Plastic: 22.0,
  "E-waste": 120.0,
  Other: 15.0,
};

/** Extra profile fields for collectors (users table has no address yet). */
const COLLECTOR_LOCAL = {
  "+919876543210": {
    address: "Shop 12, Main Market, Kothrud, Pune",
    city: "Pune",
    distanceKm: 0.6,
    rating: 4.8,
    acceptedMaterials: MATERIAL_CATEGORIES,
  },
};

const FALLBACK_COLLECTORS = [
  {
    id: "v_2",
    name: "Vijay Scrap Traders",
    phone: "+919822011223",
    rating: 4.5,
    distanceKm: 1.5,
    address: "Plot 45, Industrial Zone, Karve Nagar, Pune",
    city: "Pune",
    acceptedMaterials: ["Paper", "Metal", "Plastic"],
    rates: { Paper: 14, Metal: 40, Plastic: 25 },
  },
  {
    id: "v_3",
    name: "Anita Waste Solutions",
    phone: "+919765499887",
    rating: 4.8,
    distanceKm: 2.4,
    address: "102 FC Road, Shivajinagar, Pune",
    city: "Pune",
    acceptedMaterials: ["Metal", "E-waste", "Plastic"],
    rates: { Metal: 45, "E-waste": 125, Plastic: 30 },
  },
  {
    id: "v_4",
    name: "Swachh Kabadi",
    phone: "+919765432109",
    rating: 4.9,
    distanceKm: 3.1,
    address: "Near Metro Station, Baner, Pune",
    city: "Pune",
    acceptedMaterials: MATERIAL_CATEGORIES,
    rates: { ...DEFAULT_RATES },
  },
];

function normalizeMaterialCategory(cat) {
  const value = String(cat || "Other").toLowerCase();
  if (value.includes("waste") || value.includes("e-") || value.includes("battery")) {
    return "E-waste";
  }
  if (value.includes("metal") || value.includes("copper") || value.includes("iron")) {
    return "Metal";
  }
  if (value.includes("plastic")) {
    return "Plastic";
  }
  if (value.includes("paper") || value.includes("cardboard") || value.includes("news")) {
    return "Paper";
  }
  if (value.includes("glass") || value.includes("rubber") || value.includes("tyre")) {
    return "Other";
  }
  return "Other";
}

/** Pull this collector's rate card; fall back to seed rates only if they have none. */
function rateCardForCollector(collectorId) {
  const store = collectorRatesRoutes.ratesStore;
  if (!store || typeof store.values !== "function") {
    return [];
  }

  const all = Array.from(store.values()).filter((r) => r.isActive);
  const own = all.filter((r) => r.collectorId === collectorId);
  const source =
    own.length > 0
      ? own
      : all.filter((r) => r.collectorId === "default_collector" || !r.collectorId);

  return source.map((rate) => ({
    id: rate.id,
    materialCategory: normalizeMaterialCategory(rate.materialCategory),
    materialName: rate.materialName || rate.materialCategory || "Scrap",
    ratePerKg: Number(rate.ratePerKg) || 0,
    unit: rate.unit || "kg",
  }));
}

function ratesMapFromCard(rateCard) {
  if (!rateCard.length) {
    return { ...DEFAULT_RATES };
  }
  const rates = {};
  for (const item of rateCard) {
    const key = item.materialCategory || "Other";
    const value = Number(item.ratePerKg) || 0;
    // Keep the highest listed rate per category for summary chips.
    rates[key] = Math.max(rates[key] || 0, value);
  }
  return rates;
}

function acceptedMaterialsFromCard(rateCard) {
  const set = new Set(rateCard.map((r) => r.materialCategory).filter(Boolean));
  return set.size > 0 ? Array.from(set) : [...MATERIAL_CATEGORIES];
}

function buildVendorFromCollector(row, index) {
  const phone = row.phone || "";
  const name = row.full_name || "Kabadiwala";
  const local = COLLECTOR_LOCAL[phone] || {
    address: `${name}'s collection area, Pune`,
    city: "Pune",
    distanceKm: 0.8 + index * 0.7,
    rating: 4.6,
  };
  const rateCard = rateCardForCollector(row.public_id);
  const acceptedMaterials =
    local.acceptedMaterials || acceptedMaterialsFromCard(rateCard);

  return {
    id: row.public_id,
    name,
    shopName: `${name} · Collector`,
    phone,
    rating: local.rating,
    distanceKm: local.distanceKm,
    address: local.address,
    city: local.city,
    operatingHours: "8:00 AM - 8:00 PM",
    verified: true,
    isCollector: true,
    acceptedMaterials,
    rates: ratesMapFromCard(rateCard),
    rateCard,
  };
}

async function listCollectorVendors({ category } = {}) {
  let collectors = [];
  try {
    collectors = await queryRows(
      `SELECT public_id, full_name, phone
         FROM users
        WHERE role = 'COLLECTOR' AND is_active = TRUE
        ORDER BY full_name ASC
        LIMIT 50`
    );
  } catch (_) {
    collectors = [];
  }

  const fromDb = collectors.map((row, index) => buildVendorFromCollector(row, index));

  const seenPhones = new Set(
    fromDb.map((v) => String(v.phone || "").replace(/\D/g, "")).filter(Boolean)
  );
  // Demo seed vendors only fill gaps; live collector accounts always win.
  const extras = FALLBACK_COLLECTORS.filter(
    (v) => !seenPhones.has(String(v.phone || "").replace(/\D/g, ""))
  ).map((v) => {
    const rateCard = Object.entries(v.rates || DEFAULT_RATES).map(([materialCategory, ratePerKg]) => ({
      id: `${v.id}_${materialCategory}`,
      materialCategory,
      materialName: materialCategory,
      ratePerKg,
      unit: "kg",
    }));
    return {
      ...v,
      shopName: `${v.name} · Kabadiwala`,
      operatingHours: "8:00 AM - 8:00 PM",
      verified: true,
      isCollector: true,
      rates: v.rates || { ...DEFAULT_RATES },
      rateCard,
    };
  });

  let vendors = [...fromDb, ...extras].sort(
    (a, b) => (a.distanceKm || 99) - (b.distanceKm || 99)
  );

  if (category && String(category).trim()) {
    const cat = String(category).trim().toLowerCase();
    vendors = vendors.filter((v) =>
      (v.acceptedMaterials || []).some((m) => m.toLowerCase() === cat) ||
      (v.rateCard || []).some((r) => String(r.materialCategory || "").toLowerCase() === cat)
    );
  }

  return vendors;
}

const userRequestsStore = new Map();
const paymentsStore = [
  {
    id: "pay_101",
    transactionId: "TXN9876543210",
    amount: 540.0,
    paymentMethod: "UPI",
    status: "Completed",
    formattedDate: "Oct 3, 2026, 4:30 PM",
    vendorName: "Ramesh Kumar (Green Recyclers)",
    itemsSummary: "Cardboard & Newspaper",
    weightKg: 38.5,
  },
  {
    id: "pay_102",
    transactionId: "TXN8765432109",
    amount: 1310.0,
    paymentMethod: "Cash",
    status: "Completed",
    formattedDate: "Sep 28, 2026, 11:15 AM",
    vendorName: "Vijay Traders",
    itemsSummary: "Heavy Iron & Copper Wire",
    weightKg: 18.0,
  },
];

const collectionsStore = [
  {
    id: "col_1",
    formattedDate: "3 Oct 2026",
    vendorName: "Ramesh Kumar (Green Recyclers)",
    totalWeightKg: 38.5,
    totalAmount: 540.0,
    paymentMethod: "UPI",
    items: [
      { materialName: "Cardboard", weightKg: 20.0, ratePerKg: 10.0, subtotal: 200.0 },
      { materialName: "Newspaper", weightKg: 18.5, ratePerKg: 18.37, subtotal: 340.0 },
    ],
  },
  {
    id: "col_2",
    formattedDate: "28 Sep 2026",
    vendorName: "Vijay Traders",
    totalWeightKg: 18.0,
    totalAmount: 1310.0,
    paymentMethod: "Cash",
    items: [
      { materialName: "Heavy Metal / Iron", weightKg: 15.0, ratePerKg: 34.0, subtotal: 510.0 },
      { materialName: "Copper Wire", weightKg: 3.0, ratePerKg: 266.67, subtotal: 800.0 },
    ],
  },
];

// GET /api/user/vendors — nearby kabadiwalas (live COLLECTOR accounts + local seed)
router.get(
  "/vendors",
  asyncHandler(async (req, res) => {
    const category = req.query.category || req.query.material;
    const vendors = await listCollectorVendors({ category });
    sendSuccess(res, {
      data: {
        vendors,
        count: vendors.length,
        categories: MATERIAL_CATEGORIES,
      },
    });
  })
);

function mapCollectorStatusToUser(collectorStatus) {
  switch (String(collectorStatus || "").toUpperCase()) {
    case "PENDING":
      return "REQUEST_CREATED";
    case "ACCEPTED":
      return "KABADIWALA_ACCEPTED";
    case "ON_MY_WAY":
      return "PICKUP_SCHEDULED";
    case "COLLECTING":
      return "SCRAP_COLLECTED";
    case "COMPLETED":
      return "AMOUNT_CALCULATED";
    case "REJECTED":
    case "CANCELLED":
      return "REJECTED";
    default:
      return null;
  }
}

/** Called by pickup-requests when collector Accept / Reject / completes. */
function applyCollectorStatus(id, collectorStatus, extras = {}) {
  const existing = userRequestsStore.get(id);
  if (!existing) return null;
  const mapped = mapCollectorStatusToUser(collectorStatus);
  if (!mapped) return existing;
  const updated = {
    ...existing,
    ...extras,
    status: mapped,
    collectorStatus: collectorStatus,
    updatedAt: new Date().toISOString(),
  };
  userRequestsStore.set(id, updated);
  return updated;
}

router.applyCollectorStatus = applyCollectorStatus;

// GET /api/user/requests
router.get(
  "/requests",
  asyncHandler(async (req, res) => {
    const list = Array.from(userRequestsStore.values()).sort(
      (a, b) => new Date(b.updatedAt || 0) - new Date(a.updatedAt || 0)
    );
    sendSuccess(res, {
      data: { requests: list, count: list.length },
    });
  })
);

// GET /api/user/requests/:id — poll pickup progress after collector acts
router.get(
  "/requests/:id",
  asyncHandler(async (req, res) => {
    const request = userRequestsStore.get(req.params.id);
    if (!request) {
      return sendError(res, 404, { message: `Request ${req.params.id} not found` });
    }
    sendSuccess(res, { data: { request } });
  })
);

// POST /api/user/requests
router.post(
  "/requests",
  asyncHandler(async (req, res) => {
    const body = req.body;
    const id = body.id || `req_${Date.now()}`;
    const newRequest = {
      id,
      userId: req.user?.publicId || body.userId || "cust_1",
      userName: body.userName || req.user?.fullName || "Customer",
      userPhone: body.userPhone || req.user?.phone || "",
      pickupAddress: body.pickupAddress || "",
      latitude: body.latitude || 19.1197,
      longitude: body.longitude || 72.8464,
      preferredTimeSlot: body.preferredTimeSlot || "Today, 4:00 PM - 6:00 PM",
      materialCategory: body.materialCategory || "Paper & Cardboard",
      materialName: body.materialName || "Newspaper & Cartons",
      estimatedWeightKg: Number(body.estimatedWeightKg) || 12.5,
      ratePerKg: Number(body.ratePerKg) || 14.0,
      description: body.description || "",
      status: "REQUEST_CREATED",
      paymentStatus: "PENDING",
      collectorId: body.collectorId || "v_1",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    userRequestsStore.set(id, newRequest);
    if (typeof pickupRequestsRoutes.ingestFromUserApi === "function") {
      pickupRequestsRoutes.ingestFromUserApi(newRequest);
    }
    sendSuccess(res, { data: { request: newRequest }, status: 201 });
  })
);

// GET /api/user/payment-config — Razorpay Test Key Id only (never the secret)
router.get(
  "/payment-config",
  asyncHandler(async (req, res) => {
    const keyId = config.razorpay?.keyId || "";
    const configured =
      typeof keyId === "string" &&
      (keyId.startsWith("rzp_test_") || keyId.startsWith("rzp_live_"));
    sendSuccess(res, {
      data: {
        razorpayKeyId: configured ? keyId : null,
        mode: keyId.startsWith("rzp_live_") ? "live" : "test",
        configured,
        // Secret is intentionally omitted.
      },
    });
  })
);

// GET /api/user/payments
router.get(
  "/payments",
  asyncHandler(async (req, res) => {
    sendSuccess(res, {
      data: { payments: paymentsStore, count: paymentsStore.length },
    });
  })
);

// GET /api/user/collections
router.get(
  "/collections",
  asyncHandler(async (req, res) => {
    sendSuccess(res, {
      data: { collections: collectionsStore, count: collectionsStore.length },
    });
  })
);

module.exports = router;
