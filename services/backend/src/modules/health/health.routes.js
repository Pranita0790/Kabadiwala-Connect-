/*
|--------------------------------------------------------------------------
| HEALTH ROUTES
|--------------------------------------------------------------------------
| Unauthenticated by design: a platform health checker has no credentials.
| The endpoints expose service status only, no data.
|--------------------------------------------------------------------------
*/

const express = require("express");

const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const healthService = require("./health.service");

const router = express.Router();

// GET /health — liveness
router.get(
  "/",
  asyncHandler(async (req, res) => {
    sendSuccess(res, { data: await healthService.liveness() });
  })
);

// GET /health/ready — readiness (checks PostgreSQL and the AI service)
router.get(
  "/ready",
  asyncHandler(async (req, res) => {
    const result = await healthService.readiness();

    // 503 when a dependency is down, so the platform stops routing traffic.
    sendSuccess(res, { status: result.httpStatus, data: result });
  })
);

module.exports = router;
