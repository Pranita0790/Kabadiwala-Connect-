/*
|--------------------------------------------------------------------------
| SERVER BOOTSTRAP
|--------------------------------------------------------------------------
| Opens the port and owns process lifecycle. All routing lives in app.js.
|
| The process deliberately starts even when no database is configured: a
| deployment without DATABASE_URL keeps liveness green and serves the AI
| gateway, while DB-backed routes answer 503 with an actionable message
| (middleware/require-database.js). Set DATABASE_URL to enable them.
|--------------------------------------------------------------------------
*/

const http = require("node:http");

const app = require("./app");
const config = require("./config/env");
const logger = require("./lib/logger");
const { closePool } = require("./db/pool");
const { up: migrateUp } = require("./db/migrate");

const server = http.createServer(app);

function start() {
  server.listen(config.server.port, config.server.host, () => {
    logger.info("Kabadiwala backend listening", {
      port: config.server.port,
      host: config.server.host,
      env: config.env,
      databaseConfigured: config.database.configured,
    });

    if (!config.database.configured) {
      logger.warn(
        "DATABASE_URL is not configured. Database-backed routes will " +
          "return 503 until it is set and migrations have been run."
      );
    }
  });
}

/**
 * Apply pending SQL migrations before accepting traffic.
 * Safe / idempotent — required on fresh Render Postgres.
 */
async function applyMigrationsIfConfigured() {
  if (!config.database.configured) {
    return;
  }

  logger.info("Applying database migrations");
  const applied = await migrateUp();
  logger.info("Database migrations ready", {
    newlyApplied: Array.isArray(applied) ? applied.length : 0,
    versions: applied,
  });
}

function shutdown(signal) {
  logger.info("Shutting down", { signal });

  server.close(async () => {
    try {
      await closePool();
    } catch (error) {
      logger.error("Error while closing the database pool", {
        message: error.message,
      });
    }

    process.exit(0);
  });

  // Do not let a hung connection keep the process alive forever.
  setTimeout(() => process.exit(1), config.server.shutdownTimeoutMs).unref();
}

if (require.main === module) {
  applyMigrationsIfConfigured()
    .then(() => {
      start();
      process.on("SIGTERM", () => shutdown("SIGTERM"));
      process.on("SIGINT", () => shutdown("SIGINT"));
    })
    .catch((error) => {
      logger.error("Failed to migrate database on boot", {
        message: error.message,
        code: error.code,
      });
      // Without schema, DB routes are broken — fail fast so Render redeploys visibly.
      process.exit(1);
    });
}

module.exports = { app, server, start, shutdown, applyMigrationsIfConfigured };
