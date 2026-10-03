/*
|--------------------------------------------------------------------------
| IDENTIFIERS
|--------------------------------------------------------------------------
| Human-readable lot identifiers such as KC-2026-0148, plus the internal
| UUID used as the offline-sync idempotency key.
|--------------------------------------------------------------------------
*/

const crypto = require("node:crypto");

const { LOT_ID_PREFIX } = require("../config/constants");

/**
 * Generate the public lot reference: KC-<year>-<zero padded sequence>.
 * Uniqueness is enforced by the database; a collision raises 23505 and the
 * caller retries.
 */
function formatLotReference(year, sequence) {
  return `${LOT_ID_PREFIX}-${year}-${String(sequence).padStart(4, "0")}`;
}

/**
 * The client-side generated key the collector app uses for a lot created
 * while offline. The same value must survive re-synchronisation.
 */
function newClientReference() {
  return crypto.randomUUID();
}

function newPublicId() {
  return crypto.randomUUID();
}

/**
 * Opaque, non-guessable token for QR handovers and refresh tokens.
 * The handover QR payload contains no personal data (see the collector's
 * Handover.buildSafeQrPayload), so a random token is sufficient.
 */
function newOpaqueToken(bytes = 24) {
  return crypto.randomBytes(bytes).toString("hex");
}

/**
 * Is this value a UUID?
 *
 * Needed wherever a query hits a `uuid` column with a user-supplied value
 * that might not be one. PostgreSQL raises 22P02 (invalid_text_representation)
 * for 'KC-2026-0148' compared against a uuid column, which aborts the request
 * before any fallback lookup can run. Checking the shape first lets a caller
 * choose the right query instead.
 *
 * Accepts any version and the nil UUID; PostgreSQL accepts all of them, so
 * this should not be stricter than the database.
 */
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value) {
  return typeof value === "string" && UUID_PATTERN.test(value.trim());
}

function currentYear(now = new Date()) {
  return now.getUTCFullYear();
}

module.exports = {
  formatLotReference,
  newClientReference,
  newPublicId,
  newOpaqueToken,
  isUuid,
  currentYear,
};
