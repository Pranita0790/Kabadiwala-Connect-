/*
|--------------------------------------------------------------------------
| CORS
|--------------------------------------------------------------------------
| Allow-list based, driven by CORS_ORIGINS rather than hard-coded in source
| (the previous implementation hard-coded three origins inline).
|
| The Flutter collector app sends no Origin header, so it is unaffected by
| this policy.
|--------------------------------------------------------------------------
*/

const cors = require("cors");

const config = require("../config/env");
const logger = require("../lib/logger");

const allowedOrigins = new Set(config.cors.origins);

function corsOptionsDelegate(origin, callback) {
  // No Origin: same-origin, curl, mobile client, or a server-to-server call.
  if (!origin) {
    return callback(null, { origin: false });
  }

  if (allowedOrigins.has(origin)) {
    return callback(null, { origin: true });
  }

  logger.warn("Blocked CORS origin", { origin });

  // Returning an error (rather than a permissive response) means the browser
  // blocks the request instead of receiving a response it cannot read.
  return callback(new Error(`Origin ${origin} is not allowed by CORS policy`));
}

const corsMiddleware = cors({
  origin: corsOptionsDelegate,
  methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
  exposedHeaders: ["X-Request-Id", "RateLimit-Limit", "RateLimit-Remaining"],
  credentials: false,
  maxAge: 86_400,
});

module.exports = corsMiddleware;
module.exports.allowedOrigins = allowedOrigins;
