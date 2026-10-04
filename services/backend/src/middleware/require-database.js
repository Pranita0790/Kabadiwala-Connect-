const config = require("../config/env");
const { ServiceUnavailableError } = require("../lib/errors");

// In-memory persistent stores for local dev/offline
const memStore = {
  lots: [],
  pickupRequests: [
    {
      id: "pickup_1",
      customer_name: "Anita Sharma",
      phone: "+919822012345",
      address: "Bungalow 4, Model Colony, Pune",
      preferred_date: new Date().toISOString().split("T")[0],
      preferred_time: "10:30 AM",
      status: "SCHEDULED",
      notes: "Heavy old air conditioner and mixed scrap",
    },
    {
      id: "pickup_2",
      customer_name: "Rajesh Kulkarni",
      phone: "+919822098765",
      address: "Flat 302, Green Acres, Baner, Pune",
      preferred_date: new Date().toISOString().split("T")[0],
      preferred_time: "02:00 PM",
      status: "REQUESTED",
      notes: "Newspapers and corrugated cardboard boxes",
    },
  ],
  collectorRates: [
    { id: "cr_1", material_name: "Copper Wire", buy_rate: 620, unit: "kg" },
    { id: "cr_2", material_name: "Motherboard / PCB", buy_rate: 450, unit: "kg" },
    { id: "cr_3", material_name: "Lithium Batteries", buy_rate: 130, unit: "kg" },
    { id: "cr_4", material_name: "Iron & Heavy Steel", buy_rate: 38, unit: "kg" },
    { id: "cr_5", material_name: "Plastic (PET Bottles)", buy_rate: 24, unit: "kg" },
  ],
  handovers: [],
  notifications: [
    {
      id: "notif_1",
      title: "Welcome to Kabadiwala Connect",
      body: "Your offline collection & AI Copilot system is active.",
      createdAt: new Date().toISOString(),
      read: false,
    },
  ],
  transactions: [],
};

function requireDatabase(req, res, next) {
  if (config.database.configured) {
    return next();
  }

  // In development / local testing without Postgres, gracefully handle all endpoints
  if (config.isDevelopment || config.isTest || !config.isProduction) {
    const url = req.originalUrl || req.url;

    // 1. LOTS & OFFLINE SYNC
    if (url.includes("/api/lots")) {
      if (req.method === "POST") {
        const body = req.body || {};
        const items = Array.isArray(body.items) ? body.items : [body];
        const createdLots = items.map((primary) => {
          const lotId = primary.clientReference || primary.id || `lot_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
          const lot = {
            ...primary,
            id: lotId,
            publicId: lotId,
            lotNumber: `KC-2026-${Math.floor(Math.random() * 9000) + 1000}`,
            syncStatus: "SYNCED",
            status: primary.status || "Pending",
            createdAt: primary.createdAt || new Date().toISOString(),
          };
          memStore.lots.push(lot);
          return lot;
        });

        const primaryLot = createdLots[0];
        return res.status(201).json({
          success: true,
          data: {
            lot: primaryLot,
            lots: createdLots,
            created: true,
            result: { synced: createdLots.length, created: createdLots.length, conflicts: [] },
          },
          lot: primaryLot,
          created: true,
          result: { synced: createdLots.length, created: createdLots.length, conflicts: [] },
        });
      }

      if (req.method === "PATCH") {
        return res.status(200).json({
          success: true,
          data: { status: req.body?.status || "Accepted", updated: true },
        });
      }

      return res.status(200).json({
        success: true,
        data: { lots: memStore.lots, count: memStore.lots.length },
        lots: memStore.lots,
        count: memStore.lots.length,
      });
    }

    // 2. PICKUP REQUESTS
    if (url.includes("/api/pickup-requests")) {
      if (req.method === "POST") {
        const newReq = {
          id: `pickup_${Date.now()}`,
          ...req.body,
          status: req.body.status || "REQUESTED",
          createdAt: new Date().toISOString(),
        };
        memStore.pickupRequests.push(newReq);
        return res.status(201).json({ success: true, data: newReq });
      }
      return res.status(200).json({
        success: true,
        data: { requests: memStore.pickupRequests, count: memStore.pickupRequests.length },
      });
    }

    // 3. COLLECTOR RATES
    if (url.includes("/api/collector-rates")) {
      if (req.method === "POST" || req.method === "PUT") {
        return res.status(200).json({ success: true, data: req.body });
      }
      return res.status(200).json({
        success: true,
        data: { rates: memStore.collectorRates, count: memStore.collectorRates.length },
      });
    }

    // 4. MATERIALS & RATES CATALOG
    if (url.includes("/api/materials") || url.includes("/api/rates")) {
      const gemini = require("../clients/gemini.client");
      const rates = Object.entries(gemini.ESTIMATED_RATES).map(([mat, info], idx) => ({
        id: `rate_${idx + 1}`,
        material: mat.replace("_", " ").toUpperCase(),
        category: mat.includes("pcb") || mat.includes("battery") ? "E-Waste" : "Recyclables",
        ratePerKg: info.avg,
        unit: "kg",
        updatedAt: new Date().toLocaleDateString(),
      }));
      return res.status(200).json({
        success: true,
        data: { rates, count: rates.length },
        rates,
      });
    }

    // 5. NOTIFICATIONS
    if (url.includes("/api/notifications")) {
      return res.status(200).json({
        success: true,
        data: {
          notifications: memStore.notifications,
          total: memStore.notifications.length,
          unreadCount: 0,
        },
        notifications: memStore.notifications,
        total: memStore.notifications.length,
        unreadCount: 0,
      });
    }

    // 6. TRANSACTIONS
    if (url.includes("/api/transactions")) {
      return res.status(200).json({
        success: true,
        data: { transactions: memStore.transactions, total: memStore.transactions.length },
        transactions: memStore.transactions,
        total: memStore.transactions.length,
      });
    }

    // 7. HANDOVERS
    if (url.includes("/api/handovers")) {
      return res.status(201).json({
        success: true,
        data: { handover: req.body, created: true, verified: true },
        handover: req.body,
        created: true,
      });
    }

    // 8. TRACEABILITY
    if (url.includes("/api/traceability")) {
      return res.status(200).json({
        success: true,
        records: memStore.lots,
        data: { records: memStore.lots, total: memStore.lots.length },
      });
    }

    // 9. LOYALTY & RECYCLERS
    if (url.includes("/api/loyalty") || url.includes("/api/recyclers") || url.includes("/api/price-alerts")) {
      return res.status(200).json({
        success: true,
        data: { items: [], points: 450, tier: "Gold Champion" },
      });
    }

    // 10. AUTH
    if (url.includes("/api/auth")) {
      const { generateAccessToken } = require("../lib/tokens");
      const token = generateAccessToken({
        sub: "usr_local_collector",
        role: req.body?.role || "COLLECTOR",
        phone: req.body?.phone || req.body?.identifier || "+919876543210",
      });
      return res.status(200).json({
        success: true,
        data: {
          accessToken: token,
          token,
          user: {
            id: "usr_local_collector",
            publicId: "usr_local_collector",
            phone: req.body?.phone || req.body?.identifier || "+919876543210",
            fullName: req.body?.fullName || "Kabadiwala Collector",
            role: req.body?.role || "COLLECTOR",
          },
        },
      });
    }

    return next();
  }

  return next(
    new ServiceUnavailableError(
      "This endpoint needs the database, which is not configured on this " +
        "deployment. Set DATABASE_URL and run the migrations.",
      { reason: "DATABASE_NOT_CONFIGURED" }
    )
  );
}

module.exports = requireDatabase;
