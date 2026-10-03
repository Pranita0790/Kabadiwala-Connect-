/*
|--------------------------------------------------------------------------
| HEALTH SERVICE
|--------------------------------------------------------------------------
| Reports liveness and readiness separately.
|
|   /health      liveness  — is the process up? No dependency checks.
|   /health/ready readiness — can it actually serve traffic? Checks the DB
|                              and the AI service.
|
| A readiness check that depends on the AI service is a deliberate choice:
| the AI service is the only external dependency, and a deployment that
| cannot classify material is not useful. Liveness stays dependency-free so
| a slow dependency is never mistaken for a dead process and restarted.
|--------------------------------------------------------------------------
*/

const { checkConnection } = require("../../db/pool");
const aiClient = require("../../clients/ai-service.client");
const firebase = require("../../lib/firebase");

async function liveness() {
  return {
    success: true,
    service: "kabadiwala-backend",
    status: "ok",
    uptimeSeconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
  };
}

/**
 * @param {object} [options]
 * @param {boolean} [options.skipAi]  Skip the AI probe (used by tests)
 */
async function readiness({ skipAi = false } = {}) {
  const checks = {};

  const database = await checkConnection()
    .then(() => {
      checks.database = { status: "up" };

      return true;
    })
    .catch((error) => {
      checks.database = { status: "down", error: error.message };

      return false;
    });

  let aiUp = true;

  if (!skipAi) {
    aiUp = await aiClient
      .health()
      .then((result) => {
        checks.aiService = {
          status: result.reachable ? "up" : "down",
          latencyMs: result.latencyMs,
          circuitBreaker: result.breaker?.state ?? null,
        };

        return result.reachable;
      })
      .catch((error) => {
        checks.aiService = { status: "down", error: error.message };

        return false;
      });
  }

  /*
   | Phone sign-in availability.
   |
   | Reported, but deliberately NOT part of `ready`. With SMS OTP retired,
   | Firebase is the only way a new collector signs in, so an unset
   | FIREBASE_PROJECT_ID is a real problem — but it is not a fault in this
   | process. Failing readiness would pull the whole API out of rotation and
   | take down material capture and the recycler dashboard for everyone,
   | including collectors holding a valid session.
   |
   | The field makes the misconfiguration visible to whoever is deploying.
   */
  checks.phoneAuth = {
    status: firebase.isEnabled() ? "up" : "disabled",
    ...(firebase.isEnabled()
      ? {}
      : { hint: "FIREBASE_PROJECT_ID is not set; phone sign-in is unavailable" }),
  };

  const ready = database && aiUp;

  return {
    success: ready,
    service: "kabadiwala-backend",
    status: ready ? "ready" : "degraded",
    checks,
    timestamp: new Date().toISOString(),
    httpStatus: ready ? 200 : 503,
  };
}

module.exports = { liveness, readiness };
