/*
|--------------------------------------------------------------------------
| POSTGRES POOL
|--------------------------------------------------------------------------
| One lazily-created pool per process. Modules must call getPool() rather
| than constructing a client, otherwise a hot path can exhaust connections.
|--------------------------------------------------------------------------
*/

const { Pool } = require("pg");

const config = require("../config/env");
const logger = require("../lib/logger");

let pool = null;

function buildPoolOptions() {
  const options = {
    max: config.database.max,
    idleTimeoutMillis: config.database.idleTimeoutMillis,
    connectionTimeoutMillis: config.database.connectionTimeoutMillis,
    application_name: "kabadiwala-backend",
  };

  if (config.database.connectionString) {
    options.connectionString = config.database.connectionString;
  } else {
    options.host = config.database.host;
    options.port = config.database.port;
    options.database = config.database.name;
    options.user = config.database.user;
    options.password = config.database.password;
  }

  if (config.database.ssl) {
    options.ssl = { rejectUnauthorized: false };
  }

  return options;
}

function getPool() {
  if (pool) {
    return pool;
  }

  pool = new Pool(buildPoolOptions());

  // An idle client erroring out must not take the process down; pg will
  // discard the client and the next query will open a fresh connection.
  pool.on("error", (error) => {
    logger.error("Unexpected error on idle PostgreSQL client", {
      message: error.message,
      code: error.code,
    });
  });

  logger.info("PostgreSQL pool created", {
    max: config.database.max,
    usingConnectionString: Boolean(config.database.connectionString),
    host: config.database.connectionString
      ? undefined
      : config.database.host,
    database: config.database.connectionString
      ? undefined
      : config.database.name,
  });

  return pool;
}

/**
 * Verify connectivity. Used by /health and by the server bootstrap.
 */
async function checkConnection() {
  const client = await getPool().connect();

  try {
    const result = await client.query("SELECT 1 AS ok");

    return result.rows[0]?.ok === 1;
  } finally {
    client.release();
  }
}

async function closePool() {
  if (!pool) {
    return;
  }

  const closing = pool;

  pool = null;

  await closing.end();

  logger.info("PostgreSQL pool closed");
}

module.exports = {
  getPool,
  checkConnection,
  closePool,
};
