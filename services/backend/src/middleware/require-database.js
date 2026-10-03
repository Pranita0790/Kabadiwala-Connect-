/*
|--------------------------------------------------------------------------
| DATABASE AVAILABILITY GUARD
|--------------------------------------------------------------------------
| The modular backend is backed by PostgreSQL, but the deployment platform
| has historically run the service without a database (the legacy server was
| in-memory). To migrate without taking the process down, the server still
| BOOTS when no database is configured and only the routes that genuinely
| need persistence are refused.
|
| This middleware turns that misconfiguration into an explicit 503 with an
| actionable message, instead of letting a route reach the pool and surface a
| connection-refused error as a generic 500.
|
| It guards DB-backed routers ONLY. `/health` and `POST /api/ai/analyze` are
| deliberately left unguarded: liveness must stay green, and image
| classification does not read the database (persistence there is
| best-effort).
|--------------------------------------------------------------------------
*/

const config = require("../config/env");
const { ServiceUnavailableError } = require("../lib/errors");

function requireDatabase(req, res, next) {
  if (config.database.configured) {
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
