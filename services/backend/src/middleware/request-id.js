/*
|--------------------------------------------------------------------------
| REQUEST ID
|--------------------------------------------------------------------------
| Every request gets a correlation id, returned in the X-Request-Id header
| and echoed into every log line, so a collector's failed sync can be traced
| through the backend and into the AI service.
|--------------------------------------------------------------------------
*/

const crypto = require("node:crypto");

const HEADER = "x-request-id";
const SAFE_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

function requestId(req, res, next) {
  const inbound = req.get(HEADER);

  // Only trust an inbound id if it is well formed; otherwise a client could
  // inject newlines or oversized values into our logs.
  const requestId =
    inbound && SAFE_PATTERN.test(inbound) ? inbound : crypto.randomUUID();

  req.id = requestId;
  res.setHeader(HEADER, requestId);

  const startedAt = process.hrtime.bigint();

  res.on("finish", () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;

    require("../lib/logger").info("request", {
      requestId,
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Math.round(durationMs),
      userId: req.user?.id,
    });
  });

  next();
}

module.exports = requestId;
module.exports.HEADER = HEADER;
