/*
|--------------------------------------------------------------------------
| TEST HELPERS
|--------------------------------------------------------------------------
| Utilities shared by the integration suites. Not a test file itself.
|
| IMPORTANT: the database these run against must be a THROWAWAY. resetDb()
| truncates every application table.
|--------------------------------------------------------------------------
*/

const { closePool } = require("../../src/db/pool");

const fs = require("node:fs");
const path = require("node:path");

const hasDatabase = Boolean(process.env.TEST_DATABASE_URL);

/**
 * Skip an integration suite when no test database is configured.
 */
function describeIntegration(name, fn) {
  return hasDatabase ? describe(name, fn) : describe.skip(name, fn);
}

/**
 * Tables truncated between tests, children before parents so that TRUNCATE
 * does not need CASCADE (which is slower and hides genuine FK problems).
 */
const TABLES = [
  "traceability_events",
  "notifications",
  "price_alerts",
  "transactions",
  "handovers",
  "ai_analyses",
  "lots",
  "recycler_accepted_materials",
  "recycler_profiles",
  "otp_challenges",
  "refresh_tokens",
  "users",
  "lot_number_sequences",
];

/**
 * Reference data lives in migration 007 and must survive between tests.
 *
 * It cannot simply be excluded from the TRUNCATE list: material_rates has
 * `created_by -> users`, so `TRUNCATE users ... CASCADE` cascades into
 * material_rates and empties the rate board. CASCADE follows the foreign key
 * graph, not row contents, so NULLing the column would not prevent it.
 *
 * Instead the truncation is followed by replaying 007, which is written to be
 * idempotent (ON CONFLICT DO NOTHING / DO UPDATE) precisely so that reference
 * data can be restored this way.
 */
function replayReferenceData() {
  const file = path.join(__dirname, "..", "..", "src", "db", "migrations", "007_reference_data.sql");
  const sql = fs.readFileSync(file, "utf8");

  const { query } = require("../../src/db/query");

  return query(sql);
}

/**
 * Empty every application table so each test starts from a known state,
 * then restore the reference data the suite depends on.
 *
 * schema_migrations is deliberately left alone: the suite assumes migrations
 * have already run, and wiping the ledger would make the runner try to
 * re-apply them.
 */
async function resetDb() {
  const { query } = require("../../src/db/query");

  await query(`TRUNCATE TABLE ${TABLES.join(", ")} RESTART IDENTITY CASCADE`);
  await replayReferenceData();
}

/**
 * Monotonic counter for unique test values.
 *
 * users has UNIQUE constraints on both email and phone. Deriving values from
 * Date.now() alone collides whenever two fixtures are created inside the same
 * millisecond, which happens constantly when a suite seeds several users in
 * one beforeEach.
 */
let sequence = 0;

function unique(prefix) {
  sequence += 1;

  return `${prefix}-${process.pid}-${sequence}`;
}

/**
 * Insert a user and return the internal id.
 */
async function createUser(overrides = {}) {
  const { queryOne } = require("../../src/db/query");

  const row = await queryOne(
    `INSERT INTO users (email, phone, full_name, role, is_active, is_verified)
     VALUES ($1, $2, $3, $4, TRUE, TRUE)
     RETURNING id`,
    [
      overrides.email ?? `${unique("collector")}@test.local`,
      overrides.phone ?? unique("+919000"),
      overrides.fullName ?? "Test Collector",
      overrides.role ?? "COLLECTOR",
    ]
  );

  return row.id;
}

/**
 * Insert a recycler profile and return its internal id.
 *
 * Column names follow migration 005 exactly: contact_phone (not phone),
 * region (not state), is_authorized (not is_verified), and there is no
 * pincode or contact_name column.
 */
async function createRecycler(overrides = {}) {
  const { queryOne } = require("../../src/db/query");

  const row = await queryOne(
    `INSERT INTO recycler_profiles
       (user_id, organisation_name, contact_phone, address,
        city, region, latitude, longitude, is_authorized)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, TRUE)
     RETURNING id`,
    [
      overrides.userId ?? null,
      overrides.organisationName ?? "Test Recyclers Pvt Ltd",
      overrides.contactPhone ?? unique("+919100"),
      overrides.address ?? "1 Recycling Road",
      overrides.city ?? "Pune",
      overrides.region ?? "Maharashtra",
      overrides.latitude ?? 18.52,
      overrides.longitude ?? 73.85,
    ]
  );

  return row.id;
}

/**
 * A DTO shaped exactly like what the auth repository returns, for tests that
 * exercise ownership checks without minting a real token.
 */
function collectorUser(id, overrides = {}) {
  return {
    id,
    publicId: `11111111-1111-4111-8111-${String(id).slice(0, 12).padStart(12, "0")}`,
    role: "COLLECTOR",
    fullName: "Test Collector",
    recyclerId: null,
    ...overrides,
  };
}

async function teardown() {
  await closePool();
}

module.exports = {
  hasDatabase,
  describeIntegration,
  resetDb,
  createUser,
  createRecycler,
  collectorUser,
  unique,
  teardown,
};