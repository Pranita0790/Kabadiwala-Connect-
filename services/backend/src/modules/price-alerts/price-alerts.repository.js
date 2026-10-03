/*
|--------------------------------------------------------------------------
| PRICE ALERTS REPOSITORY
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, insertOne, transaction } = require("../../db/query");
const { newPublicId } = require("../../lib/ids");

function toAlert(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.public_id,
    userId: row.user_id,
    materialId: row.material_id,
    region: row.region,
    targetRatePerKg: Number(row.target_rate_per_kg),
    direction: row.direction,
    isActive: row.is_active,
    triggeredAt: row.triggered_at,
    createdAt: row.created_at,
  };
}

async function create({
  userId,
  materialId,
  region,
  targetRatePerKg,
  direction,
}) {
  const row = await insertOne(
    "price_alerts",
    {
      public_id: newPublicId(),
      user_id: userId,
      material_id: materialId,
      region,
      target_rate_per_kg: targetRatePerKg,
      direction,
      is_active: true,
    },
    { label: "priceAlerts:create" }
  );

  return toAlert(row);
}

async function listForUser(userId, { limit = 25, offset = 0, activeOnly = false } = {}) {
  const filters = ["user_id = $1"];
  const params = [userId];

  if (activeOnly) {
    filters.push("is_active AND triggered_at IS NULL");
  }

  params.push(limit, offset);

  const rows = await queryRows(
    `SELECT *
     FROM price_alerts
     WHERE ${filters.join(" AND ")}
     ORDER BY created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
    { label: "priceAlerts:list" }
  );

  return rows.map(toAlert);
}

async function countForUser(userId) {
  const row = await queryOne(
    "SELECT COUNT(*)::int AS total FROM price_alerts WHERE user_id = $1",
    [userId],
    { label: "priceAlerts:count" }
  );

  return row?.total ?? 0;
}

async function findOwnedByPublicId(userId, publicId) {
  const row = await queryOne(
    "SELECT * FROM price_alerts WHERE public_id = $1 AND user_id = $2",
    [publicId, userId],
    { label: "priceAlerts:findOwned" }
  );

  return toAlert(row);
}

/**
 * Active alerts whose condition the given rate satisfies.
 *
 * ABOVE means "tell me when it rises to or past my target"; BELOW means "tell
 * me when it falls to or under my target".
 */
/**
 * Find alerts whose threshold the supplied rate has just crossed.
 *
 * Returns RAW rows, not DTOs, and that is deliberate: markTriggered() needs
 * the internal primary key to do `WHERE id = ANY(...)`, whereas toAlert()
 * exposes public_id as `id` because that is what belongs in a URL. Returning
 * DTOs here would hand markTriggered() public ids and silently match nothing.
 */
async function findMatching({ materialId, region, ratePerKg }) {
  const rows = await queryRows(
    `SELECT *
     FROM price_alerts
     WHERE material_id = $1
       AND region = $2
       AND is_active
       AND triggered_at IS NULL
       AND (
         (direction = 'ABOVE' AND $3 >= target_rate_per_kg)
         OR (direction = 'BELOW' AND $3 <= target_rate_per_kg)
       )`,
    [materialId, region, ratePerKg],
    { label: "priceAlerts:findMatching" }
  );

  return rows;
}

/**
 * Mark alerts triggered. Returns only the rows this call actually claimed,
 * so two concurrent rate updates cannot both notify the same collector.
 */
async function markTriggered(ids) {
  if (!Array.isArray(ids) || ids.length === 0) {
    return [];
  }

  return transaction(async (client) => {
    const rows = await queryRows(
      `UPDATE price_alerts
       SET triggered_at = NOW(), is_active = FALSE
       WHERE id = ANY($1::uuid[]) AND triggered_at IS NULL
       RETURNING *`,
      [ids],
      { client, label: "priceAlerts:markTriggered" }
    );

    return rows.map(toAlert);
  });
}

async function deactivate(userId, publicId) {
  const row = await queryOne(
    `UPDATE price_alerts
     SET is_active = FALSE
     WHERE public_id = $1 AND user_id = $2 AND is_active
     RETURNING *`,
    [publicId, userId],
    { label: "priceAlerts:deactivate" }
  );

  return toAlert(row);
}

module.exports = {
  create,
  listForUser,
  countForUser,
  findOwnedByPublicId,
  findMatching,
  markTriggered,
  deactivate,
  toAlert,
};