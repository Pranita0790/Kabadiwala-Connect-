/*
|--------------------------------------------------------------------------
| NOTIFICATIONS REPOSITORY
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, insertOne } = require("../../db/query");

const COLUMNS = `
  id, public_id, user_id, lot_id, type,
  title_en, title_hi, title_mr,
  body_en, body_hi, body_mr,
  is_read, read_at, created_at
`;

function toNotification(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.public_id,
    userId: row.user_id,
    lotId: row.lot_id,
    type: row.type,
    title: {
      en: row.title_en,
      hi: row.title_hi,
      mr: row.title_mr,
    },
    body: {
      en: row.body_en,
      hi: row.body_hi,
      mr: row.body_mr,
    },
    isRead: row.is_read,
    readAt: row.read_at,
    createdAt: row.created_at,
  };
}

async function create({
  userId,
  lotId = null,
  type,
  titleEn,
  bodyEn,
  titleHi = null,
  titleMr = null,
  bodyHi = null,
  bodyMr = null,
}) {
  const row = await insertOne(
    "notifications",
    {
      user_id: userId,
      lot_id: lotId,
      type,
      title_en: titleEn,
      title_hi: titleHi,
      title_mr: titleMr,
      body_en: bodyEn,
      body_hi: bodyHi,
      body_mr: bodyMr,
    },
    { label: "notifications:create" }
  );

  return toNotification(row);
}

/**
 * Many notifications in one insert, used when a rate change triggers several
 * price alerts.
 */
async function createMany(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return [];
  }

  const values = [];
  const placeholders = items.map((item, index) => {
    const base = index * 10;

    values.push(
      item.userId,
      item.lotId ?? null,
      item.type,
      item.titleEn,
      item.titleHi ?? null,
      item.titleMr ?? null,
      item.bodyEn,
      item.bodyHi ?? null,
      item.bodyMr ?? null,
      null
    );

    return `(${Array.from({ length: 10 }, (_, i) => `$${base + i + 1}`).join(", ")})`;
  });

  const rows = await queryRows(
    `INSERT INTO notifications
       (user_id, lot_id, type, title_en, title_hi, title_mr, body_en, body_hi, body_mr)
     VALUES ${placeholders.join(", ")}
     RETURNING ${COLUMNS}`,
    values,
    { label: "notifications:createMany" }
  );

  return rows.map(toNotification);
}

async function listForUser(userId, { limit = 25, offset = 0, unreadOnly = false }) {
  const filters = ["user_id = $1"];
  const params = [userId];

  if (unreadOnly) {
    filters.push("NOT is_read");
  }

  params.push(limit, offset);

  return queryRows(
    `SELECT ${COLUMNS}
     FROM notifications
     WHERE ${filters.join(" AND ")}
     ORDER BY created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
    { label: "notifications:list" }
  );
}

async function countForUser(userId, { unreadOnly = false } = {}) {
  const filters = ["user_id = $1"];
  const params = [userId];

  if (unreadOnly) {
    filters.push("NOT is_read");
  }

  const row = await queryOne(
    `SELECT COUNT(*)::int AS total
     FROM notifications
     WHERE ${filters.join(" AND ")}`,
    params,
    { label: "notifications:count" }
  );

  return row?.total ?? 0;
}

async function markRead(userId, publicId) {
  const row = await queryOne(
    `UPDATE notifications
     SET is_read = TRUE, read_at = NOW()
     WHERE public_id = $2 AND user_id = $1
     RETURNING ${COLUMNS}`,
    [userId, publicId],
    { label: "notifications:markRead" }
  );

  return toNotification(row);
}

async function markAllRead(userId) {
  const rows = await queryRows(
    `UPDATE notifications
     SET is_read = TRUE, read_at = NOW()
     WHERE user_id = $1 AND NOT is_read
     RETURNING id`,
    [userId],
    { label: "notifications:markAllRead" }
  );

  return rows.length;
}

module.exports = {
  create,
  createMany,
  listForUser,
  countForUser,
  markRead,
  markAllRead,
  toNotification,
};