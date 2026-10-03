/*
|--------------------------------------------------------------------------
| EXPRESS APPLICATION
|--------------------------------------------------------------------------
| The full middleware stack and every API router, assembled in one place.
| server.js is only a bootstrap (listen + graceful shutdown) so the app can
| be required by tests without opening a port.
|
| Route map:
|   GET  /                          service index
|   GET  /health, /health/ready      liveness + readiness (no DB required)
|   POST /api/ai/analyze             AI gateway (no DB required)
|   /api/auth/*                      registration, sessions, Firebase sign-in
|   /api/materials/*                 material catalogue
|   /api/rates/*  /api/prices/*      rate card (prices is the collector alias)
|   /api/lots/*                      lots, offline sync, AI analyses
|   /api/recyclers/*                 recycler directory (collector matching)
|   /api/handovers/*                 handover create / confirm
|   /api/transactions/*              earnings / settlement ledger
|   /api/traceability/*              traceability timeline
|   /api/notifications/*             collector notifications
|   /api/price-alerts/*              collector price alerts
|
| Everything under /api except /api/ai is behind the database guard: it
| returns 503 rather than a connection-refused 500 when no database is
| configured (see middleware/require-database.js).
|--------------------------------------------------------------------------
*/

const express = require("express");

const config = require("./config/env");
const requestId = require("./middleware/request-id");
const security = require("./middleware/security");
const corsMiddleware = require("./middleware/cors");
const requireDatabase = require("./middleware/require-database");
const { defaultLimiter } = require("./middleware/rate-limit");
const { notFound, errorHandler } = require("./middleware/error-handler");
const asyncHandler = require("./lib/async-handler");
const { sendSuccess } = require("./lib/response");

const healthRoutes = require("./modules/health/health.routes");
const healthService = require("./modules/health/health.service");
const authRoutes = require("./modules/auth/auth.routes");
const materialsRoutes = require("./modules/materials/materials.routes");
const ratesRoutes = require("./modules/rates/rates.routes");
const lotsRoutes = require("./modules/lots/lots.routes");
const recyclersRoutes = require("./modules/recyclers/recyclers.routes");
const handoversRoutes = require("./modules/handovers/handovers.routes");
const transactionsRoutes = require("./modules/transactions/transactions.routes");
const traceabilityRoutes = require("./modules/traceability/traceability.routes");
const notificationsRoutes = require("./modules/notifications/notifications.routes");
const priceAlertsRoutes = require("./modules/price-alerts/price-alerts.routes");
const pickupRequestsRoutes = require("./modules/pickup-requests/pickup-requests.routes");
const collectorRatesRoutes = require("./modules/collector-rates/collector-rates.routes");
const userApiRoutes = require("./modules/user-api/user-api.routes");
const aiRoutes = require("./modules/ai/ai.routes");

const app = express();

// Behind Render's proxy; required for correct client IPs in the rate limiter.
app.set("trust proxy", true);
app.disable("x-powered-by");
// Dynamic lot/transaction lists must not be served as 304 with an empty body
// to the recycler dashboard (stale empty cache looked like "nothing syncing").
app.set("etag", false);

/*
|--------------------------------------------------------------------------
| GLOBAL MIDDLEWARE
|--------------------------------------------------------------------------
*/

app.use(requestId);
app.use(security);
app.use(corsMiddleware);
app.use(express.json({ limit: config.server.bodyLimit }));
app.use(express.urlencoded({ extended: false, limit: config.server.bodyLimit }));
app.use(defaultLimiter);

/*
|--------------------------------------------------------------------------
| INDEX
|--------------------------------------------------------------------------
*/

app.get("/", (req, res) => {
  sendSuccess(res, {
    message: "Kabadiwala Connect Backend API",
    data: {
      service: "kabadiwala-backend",
      version: "1.1.0",
      endpoints: {
        health: "/health",
        readiness: "/health/ready",
        aiAnalyze: "/api/ai/analyze",
        auth: "/api/auth",
        materials: "/api/materials",
        rates: "/api/rates",
        prices: "/api/prices",
        lots: "/api/lots",
        recyclers: "/api/recyclers",
        handovers: "/api/handovers",
        transactions: "/api/transactions",
        traceability: "/api/traceability",
        notifications: "/api/notifications",
        priceAlerts: "/api/price-alerts",
        pickupRequests: "/api/pickup-requests",
        collectorRates: "/api/collector-rates",
      },
    },
  });
});

/*
|--------------------------------------------------------------------------
| HEALTH — no database guard
|--------------------------------------------------------------------------
*/

app.use("/health", healthRoutes);

// Alias promised by docs/api/api-contract.md.
app.get(
  "/health/live",
  asyncHandler(async (req, res) =>
    sendSuccess(res, { data: await healthService.liveness() })
  )
);

/*
|--------------------------------------------------------------------------
| AI GATEWAY — no database guard
|--------------------------------------------------------------------------
*/

app.use("/api/ai", aiRoutes);

/*
|--------------------------------------------------------------------------
| DATA-BACKED ROUTES — require a configured database
|--------------------------------------------------------------------------
*/

app.use("/api/auth", requireDatabase, authRoutes);
app.use("/api/materials", requireDatabase, materialsRoutes);
app.use("/api/rates", requireDatabase, ratesRoutes);
app.use("/api/prices", requireDatabase, ratesRoutes);
app.use("/api/lots", requireDatabase, lotsRoutes);
app.use("/api/recyclers", requireDatabase, recyclersRoutes);
app.use("/api/handovers", requireDatabase, handoversRoutes);
app.use("/api/transactions", requireDatabase, transactionsRoutes);
app.use("/api/traceability", requireDatabase, traceabilityRoutes);
app.use("/api/notifications", requireDatabase, notificationsRoutes);
app.use("/api/price-alerts", requireDatabase, priceAlertsRoutes);
app.use("/api/pickup-requests", pickupRequestsRoutes);
app.use("/api/collector-rates", collectorRatesRoutes);
app.use("/api/user", userApiRoutes);

/*
|--------------------------------------------------------------------------
| 404 + ERROR HANDLING
|--------------------------------------------------------------------------
*/

app.use(notFound);
app.use(errorHandler);

module.exports = app;
