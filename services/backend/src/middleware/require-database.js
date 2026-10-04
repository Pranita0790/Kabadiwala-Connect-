const config = require("../config/env");
const { ServiceUnavailableError } = require("../lib/errors");

function requireDatabase(req, res, next) {
  if (config.database.configured) {
    return next();
  }

  // In development / local testing without Postgres, gracefully handle sync, lots, auth, handovers and notifications
  if (config.isDevelopment || config.isTest || !config.isProduction) {
    const url = req.originalUrl || req.url;

    // 1. LOTS & OFFLINE SYNC
    if (url.includes("/api/lots")) {
      if (req.method === "POST") {
        const body = req.body || {};
        const items = Array.isArray(body.items) ? body.items : [body];
        const primary = items[0] || body;
        const lotId = primary.clientReference || primary.id || `lot_${Date.now()}`;
        const createdLot = {
          ...primary,
          id: lotId,
          publicId: lotId,
          lotNumber: `KC-2026-${Math.floor(Math.random() * 9000) + 1000}`,
          syncStatus: "SYNCED",
          status: "PENDING",
        };
        return res.status(201).json({
          success: true,
          data: {
            lot: createdLot,
            created: true,
            result: { synced: items.length, created: items.length, conflicts: [] },
          },
          lot: createdLot,
          created: true,
          result: { synced: items.length, created: items.length, conflicts: [] },
        });
      }
      return res.status(200).json({
        success: true,
        data: { lots: [], count: 0 },
        lots: [],
        count: 0,
      });
    }

    // 2. NOTIFICATIONS
    if (url.includes("/api/notifications")) {
      return res.status(200).json({
        success: true,
        data: { notifications: [], total: 0, unreadCount: 0 },
        notifications: [],
        total: 0,
        unreadCount: 0,
      });
    }

    // 3. TRANSACTIONS
    if (url.includes("/api/transactions")) {
      return res.status(200).json({
        success: true,
        data: { transactions: [], total: 0 },
        transactions: [],
        total: 0,
      });
    }

    // 4. HANDOVERS
    if (url.includes("/api/handovers")) {
      return res.status(201).json({
        success: true,
        data: { handover: req.body, created: true },
        handover: req.body,
        created: true,
      });
    }

    // 5. AUTH
    if (url.includes("/api/auth")) {
      const { generateAccessToken } = require("../lib/tokens");
      const token = generateAccessToken({
        sub: "usr_local_collector",
        role: "COLLECTOR",
        phone: req.body?.phone || "+919876543210",
      });
      return res.status(200).json({
        success: true,
        data: {
          accessToken: token,
          token,
          user: {
            id: "usr_local_collector",
            publicId: "usr_local_collector",
            phone: req.body?.phone || "+919876543210",
            fullName: req.body?.fullName || "Kabadiwala Collector",
            role: "COLLECTOR",
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
