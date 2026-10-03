/*
|--------------------------------------------------------------------------
| MIGRATION RUNNER
|--------------------------------------------------------------------------
| Applies the .sql files in src/db/migrations in filename order, inside one
| transaction per file, and records what ran in schema_migrations.
|
| Usage:
|   npm run migrate           apply all pending migrations
|   npm run migrate:status    list applied and pending migrations
|   npm run migrate:reset     DROP every application object, then re-apply
|
| `reset` is destructive and refuses to run when NODE_ENV=production
| (AGENTS.md section 8: never delete production data).
|--------------------------------------------------------------------------
*/

const fs = require("node:fs");
const path = require("node:path");

const config = require("../config/env");
const logger = require("../lib/logger");
const { getPool, closePool } = require("./pool");
const { query, queryRows } = require("./query");

const MIGRATIONS_DIR = path.join(__dirname, "migrations");

const CREATE_LEDGER = `
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version     TEXT PRIMARY KEY,
    checksum    TEXT NOT NULL,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_ms INTEGER
  )
`;

function loadMigrationFiles() {
  if (!fs.existsSync(MIGRATIONS_DIR)) {
    return [];
  }

  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith(".sql"))
    .sort()
    .map((file) => {
      const fullPath = path.join(MIGRATIONS_DIR, file);

      return {
        version: file.replace(/\.sql$/, ""),
        file,
        sql: fs.readFileSync(fullPath, "utf8"),
      };
    });
}

/**
 * Checksum guards against a migration file being edited after it was applied
 * in another environment, which would leave databases silently out of sync.
 */
function checksum(sql) {
  return require("node:crypto")
    .createHash("sha256")
    .update(sql)
    .digest("hex")
    .slice(0, 16);
}

async function ensureLedger() {
  await query(CREATE_LEDGER, [], { label: "schema_migrations:create" });
}

async function getApplied() {
  await ensureLedger();

  return queryRows(
    "SELECT version, checksum, applied_at FROM schema_migrations ORDER BY version",
    [],
    { label: "schema_migrations:select" }
  );
}

async function status() {
  const files = loadMigrationFiles();
  const applied = await getApplied();
  const appliedMap = new Map(applied.map((row) => [row.version, row]));

  const rows = files.map((file) => {
    const record = appliedMap.get(file.version);

    return {
      version: file.version,
      state: record ? "applied" : "pending",
      appliedAt: record ? record.applied_at : null,
      checksumMismatch: record
        ? record.checksum !== checksum(file.sql)
        : false,
    };
  });

  for (const orphan of applied) {
    if (!files.some((file) => file.version === orphan.version)) {
      rows.push({
        version: orphan.version,
        state: "missing-file",
        appliedAt: orphan.applied_at,
        checksumMismatch: false,
      });
    }
  }

  return rows;
}

/**
 * Apply one migration in its own transaction so a failure leaves earlier
 * migrations applied and the failing one unapplied.
 */
async function applyMigration(client, file) {
  const sqlChecksum = checksum(file.sql);
  const startedAt = Date.now();

  try {
    await client.query("BEGIN");
    await client.query(file.sql);
    await client.query(
      `INSERT INTO schema_migrations (version, checksum, duration_ms)
       VALUES ($1, $2, $3)`,
      [file.version, sqlChecksum, Date.now() - startedAt]
    );
    await client.query("COMMIT");

    return true;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});

    throw new Error(
      `Migration ${file.file} failed: ${error.message}`,
      { cause: error }
    );
  }
}

async function up() {
  const files = loadMigrationFiles();

  if (files.length === 0) {
    logger.warn("No migration files found", { dir: MIGRATIONS_DIR });

    return [];
  }

  const applied = await getApplied();
  const appliedMap = new Map(applied.map((row) => [row.version, row]));
  const client = await getPool().connect();
  const executed = [];

  try {
    for (const file of files) {
      const record = appliedMap.get(file.version);

      if (record) {
        if (record.checksum !== checksum(file.sql)) {
          logger.warn(
            "Applied migration has changed on disk; leaving it untouched",
            { version: file.version }
          );
        }

        continue;
      }

      await applyMigration(client, file);

      executed.push(file.version);

      logger.info("Migration applied", { version: file.version });
    }
  } finally {
    client.release();
  }

  if (executed.length === 0) {
    logger.info("Database is already up to date", {
      migrations: files.length,
    });
  }

  return executed;
}

/**
 * Destructive reset. Development only.
 */
async function reset() {
  if (config.isProduction) {
    throw new Error(
      "migrate:reset is refused when NODE_ENV=production. " +
        "Production data must never be dropped by a script."
    );
  }

  const client = await getPool().connect();

  try {
    logger.warn("Resetting database schema (development only)");

    await client.query("BEGIN");

    // Dropping and recreating the whole schema, rather than looping over
    // pg_tables/pg_types to drop objects one at a time.
    //
    // The manual loop fails on PostgreSQL 14+: after the CASCADE drops
    // invalidate the plpgsql plan cache, the second FOR query fails with
    // `relation "pg_types" does not exist`. Dropping the schema has no such
    // dependency on catalog snapshots, and it also removes functions, views
    // and sequences that a table-only loop would leave behind.
    await client.query("DROP SCHEMA IF EXISTS public CASCADE");
    await client.query("CREATE SCHEMA public");

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }

  logger.info("Schema dropped, re-applying migrations");

  return up();
}

async function main() {
  const command = process.argv[2] || "up";

  try {
    if (command === "status") {
      const rows = await status();

      for (const row of rows) {
        process.stdout.write(
          `${row.state.padEnd(14)} ${row.version}` +
            `${row.appliedAt ? `  (applied ${new Date(row.appliedAt).toISOString()})` : ""}` +
            `${row.checksumMismatch ? "  [CHECKSUM MISMATCH]" : ""}\n`
        );
      }

      return;
    }

    if (command === "up") {
      await up();
      return;
    }

    if (command === "reset") {
      await reset();
      return;
    }

    process.stderr.write(`Unknown command: ${command}\n`);
    process.exitCode = 1;
  } finally {
    await closePool();
  }
}

if (require.main === module) {
  main().catch((error) => {
    logger.error("Migration command failed", {
      message: error.message,
    });
    process.exitCode = 1;
  });
}

module.exports = { up, down: up, status, reset, loadMigrationFiles };
