const express = require("express");
const router = express.Router();
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess, sendError } = require("../../lib/response");

// In-memory data store for User/Customer APIs
const vendorsStore = [
  {
    id: "v_1",
    name: "Ramesh Kumar",
    shopName: "Green Recyclers Shop #4",
    phone: "+91 98765 43210",
    rating: 4.8,
    distanceKm: 0.8,
    address: "Shop 12, Main Market, Kothrud, Pune",
    operatingHours: "8:00 AM - 8:00 PM",
    verified: true,
    rates: {
      "Newspaper": 14.0,
      "Cardboard": 10.0,
      "Plastic Bottles": 16.0,
      "Heavy Metal / Iron": 32.0,
      "Copper Wire": 450.0,
      "E-Waste / Circuit Boards": 120.0,
    },
  },
  {
    id: "v_2",
    name: "Vijay Traders",
    shopName: "Vijay Scrap Yard",
    phone: "+91 98123 45678",
    rating: 4.6,
    distanceKm: 1.5,
    address: "Plot 45, Industrial Zone, Karve Nagar, Pune",
    operatingHours: "9:00 AM - 7:30 PM",
    verified: true,
    rates: {
      "Newspaper": 13.5,
      "Cardboard": 11.0,
      "Plastic Bottles": 15.0,
      "Heavy Metal / Iron": 35.0,
      "Copper Wire": 440.0,
      "E-Waste / Circuit Boards": 110.0,
    },
  },
  {
    id: "v_3",
    name: "Swachh Kabadi",
    shopName: "Eco Clean Recycling Depot",
    phone: "+91 97654 32109",
    rating: 4.9,
    distanceKm: 2.2,
    address: "Near Metro Station, Baner, Pune",
    operatingHours: "8:30 AM - 9:00 PM",
    verified: true,
    rates: {
      "Newspaper": 15.0,
      "Cardboard": 12.0,
      "Plastic Bottles": 18.0,
      "Heavy Metal / Iron": 30.0,
      "Copper Wire": 460.0,
      "E-Waste / Circuit Boards": 130.0,
    },
  },
];

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

// GET /api/user/vendors
router.get(
  "/vendors",
  asyncHandler(async (req, res) => {
    sendSuccess(res, {
      data: { vendors: vendorsStore, count: vendorsStore.length },
    });
  })
);

// GET /api/user/requests
router.get(
  "/requests",
  asyncHandler(async (req, res) => {
    const list = Array.from(userRequestsStore.values());
    sendSuccess(res, {
      data: { requests: list, count: list.length },
    });
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
      userId: body.userId || "cust_1",
      userName: body.userName || "Ananya Sharma",
      userPhone: body.userPhone || "+91 98765 43210",
      pickupAddress: body.pickupAddress || "B-402, Green Acres, Andheri East, Mumbai",
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
    sendSuccess(res, { data: { request: newRequest }, status: 201 });
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
