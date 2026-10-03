/*
|--------------------------------------------------------------------------
| RATE LIMITING
|--------------------------------------------------------------------------
| Fixed-window, in-process limiter.
|
| Limitation, stated plainly: this is per instance. With more than one
| backend instance the effective limit multiplies by the instance count.
| A shared store (Redis) is the correct answer for a multi-instance
| deployment; see docs/architecture/system-architecture.md.
|
| No external store is used now because one is not needed at demo scale,
| and adding Redis would be dependency sprawl for no current benefit
| (AGENTS.md section 13).
|--------------------------------------------------------------------------
*/

const config = require("../config/env");
const { RateLimitError } = require("../lib/errors");

const WINDOW_MS = 60_000;

const buckets = new Map();

function clientKey(req) {
  if (req.user) {
    return `user:${req.user.id}`;
  }

  // Trust the proxy only when it is actually in front of us.
  const forwarded = req.get("x-forwarded-for");

  if (forwarded && config.server.host !== "127.0.0.1") {
    return `ip:${forwarded.split(",")[0].trim()}`;
  }

  return `ip:${req.ip || "unknown"}`;
}

function prune(bucket, now) {
  for (const [key, entry] of bucket) {
    if (entry.resetAt <= now) {
      bucket.delete(key);
    }
  }
}

/**
 * @param {object} options
 * @param {number} options.limit        Requests allowed per window
 * @param {string} [options.scope]      Bucket namespace, e.g. "ai"
 * @param {string} [options.message]    Error message when exceeded
 */
function rateLimit({ limit, scope = "default", message }) {
  const effectiveLimit = limit ?? config.rateLimit.defaultPerMinute;

  return function limitRequests(req, res, next) {
    if (!config.rateLimit.enabled || effectiveLimit <= 0) {
      return next();
    }

    const now = Date.now();
    const key = `${scope}:${clientKey(req)}`;

    if (buckets.size > 10_000) {
      prune(buckets, now);
    }

    let entry = buckets.get(key);

    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + WINDOW_MS };
      buckets.set(key, entry);
    }

    entry.count += 1;

    const remaining = Math.max(0, effectiveLimit - entry.count);

    res.setHeader("RateLimit-Limit", effectiveLimit);
    res.setHeader("RateLimit-Remaining", remaining);
    res.setHeader("RateLimit-Reset", Math.ceil(entry.resetAt / 1000));

    if (entry.count > effectiveLimit) {
      res.setHeader("Retry-After", Math.ceil((entry.resetAt - now) / 1000));

      return next(
        new RateLimitError(message || "Too many requests, please slow down", {
          limit: effectiveLimit,
          windowSeconds: Math.round(WINDOW_MS / 1000),
          retryAfterSeconds: Math.ceil((entry.resetAt - now) / 1000),
        })
      );
    }

    next();
  };
}

// Tighter limit on AI analysis: inference is the most expensive operation
// and a single misbehaving client can saturate the Python service.
const aiAnalyzeLimiter = rateLimit({
  limit: config.rateLimit.aiAnalyzePerMinute,
  scope: "ai",
  message: "Too many analysis requests. Please try again shortly.",
});

// Tighter limit on credential endpoints, to slow down brute force.
const authLimiter = rateLimit({
  limit: config.rateLimit.authPerMinute,
  scope: "auth",
  message: "Too many authentication attempts. Please try again later.",
});

const defaultLimiter = rateLimit({
  limit: config.rateLimit.defaultPerMinute,
  scope: "default",
});

/** Test helper: forget all counters. */
function reset() {
  buckets.clear();
}

module.exports = rateLimit;
module.exports.rateLimit = rateLimit;
module.exports.aiAnalyzeLimiter = aiAnalyzeLimiter;
module.exports.authLimiter = authLimiter;
module.exports.defaultLimiter = defaultLimiter;
module.exports.reset = reset;
