/*
|--------------------------------------------------------------------------
| SECURITY HEADERS
|--------------------------------------------------------------------------
| helmet defaults, relaxed only where the API genuinely serves
| cross-origin content to the Recycler Dashboard.
|--------------------------------------------------------------------------
*/

const helmet = require("helmet");

module.exports = helmet({
  // The API returns JSON only; the only cross-origin client is the
  // dashboard, which does not need framing or legacy browser features.
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'none'"],
      frameAncestors: ["'none'"],
      baseUri: ["'none'"],
      formAction: ["'none'"],
    },
  },
  crossOriginResourcePolicy: { policy: "cross-origin" },
  crossOriginEmbedderPolicy: false,
  referrerPolicy: { policy: "no-referrer" },
  // Do not advertise the framework and its version.
  hidePoweredBy: true,
  // HSTS only makes sense over TLS; harmless when the platform terminates TLS.
  hsts: {
    maxAge: 31_536_000,
    includeSubDomains: true,
    preload: false,
  },
});
