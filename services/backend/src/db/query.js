/*
|--------------------------------------------------------------------------
| QUERY HELPERS
|--------------------------------------------------------------------------
| All SQL execution goes through here so that:
|   - no SQL string is ever built by concatenating user input (parameterised
|     queries only, AGENTS.md section 9)
|   - transactions are handled in one place
|   - Postgres error codes can be translated into AppError
|--------------------------------------------------------------------------
*/

const { getPool } = require("./pool");
const logger = require("../lib/logger");
const {
  ConflictError,
  NotFoundError,
  ValidationError,
  AppError,
} = require("../lib/errors");

const DEFAULT_STATEMENT_TIMEOUT_MS = 10_000;

/**
 * Translate a Postgres driver error into a domain error.
 * `constraint` is the name of the constraint that was violated.
 */
function translatePgError(error) {
  switch (error.code) {
    case "23505": // unique_violation
      return new ConflictError(
        "A record with these details already exists",
        "DUPLICATE_RECORD",
        { constraint: error.constraint }
      );

    case "23503": // foreign_key_violation
      return new ValidationError(
        "Referenced record does not exist",
        { constraint: error.constraint }
      );

    case "23502": // not_null_violation
      return new ValidationError("A required field is missing", {
        column: error.column,
      });

    case "23514": // check_violation
      return new ValidationError("A field value is outside the allowed range", {
        constraint: error.constraint,
      });

    case "22P02": // invalid_text_representation
      return new ValidationError("Malformed identifier or value");

    case "P0002": // no_data_found
      return new NotFoundError();

    default:
      return null;
  }
}

/**
 * Run a parameterised query.
 *
 * @param {string} text
 * @param {Array<any>} [params]
 * @param {object} [options] { client, timeoutMs, label }
 */
async function query(text, params = [], options = {}) {
  const client = options.client || getPool();
  const timeout = options.timeoutMs ?? DEFAULT_STATEMENT_TIMEOUT_MS;

  const startedAt = process.hrtime.bigint();

  try {
    const result = await client.query({
      text,
      values: params,
      query_timeout: timeout,
    });

    return result;
  } catch (error) {
    const translated = translatePgError(error);

    if (translated) {
      throw translated;
    }

    logger.error("Database query failed", {
      label: options.label,
      code: error.code,
      detail: error.detail,
      message: error.message,
    });

    throw error;
  } finally {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;

    if (durationMs > 1000) {
      logger.warn("Slow database query", {
        label: options.label,
        durationMs: Math.round(durationMs),
      });
    }
  }
}

/**
 * Convenience wrapper returning rows.
 */
async function queryRows(text, params = [], options = {}) {
  const result = await query(text, params, options);

  return result.rows;
}

/**
 * Convenience wrapper returning the first row or null.
 */
async function queryOne(text, params = [], options = {}) {
  const rows = await queryRows(text, params, options);

  return rows.length > 0 ? rows[0] : null;
}

/**
 * Run `work` inside a transaction, committing on success and rolling back on
 * any throw. The callback receives a dedicated client.
 */
async function transaction(work) {
  const client = await getPool().connect();

  try {
    await client.query("BEGIN");

    const result = await work(client);

    await client.query("COMMIT");

    return result;
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (rollbackError) {
      logger.error("Transaction rollback failed", {
        message: rollbackError.message,
      });
    }

    throw error;
  } finally {
    client.release();
  }
}

/**
 * Postgres `INSERT ... RETURNING *` helper.
 */
async function insertOne(table, values, { client, label } = {}) {
  const columns = Object.keys(values);
  const placeholders = columns.map((_, index) => `$${index + 1}`);
  const params = columns.map((column) => values[column]);

  const sql =
    `INSERT INTO ${table} (${columns.join(", ")}) ` +
    `VALUES (${placeholders.join(", ")}) RETURNING *`;

  const row = await queryOne(sql, params, { client, label: label || table });

  if (!row) {
    throw new AppError(`Failed to insert into ${table}`, {
      status: 500,
      code: "INSERT_FAILED",
    });
  }

  return row;
}

module.exports = {
  query,
  queryRows,
  queryOne,
  transaction,
  insertOne,
  translatePgError,
};
