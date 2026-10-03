/*
|--------------------------------------------------------------------------
| TRANSACTIONS REPOSITORY
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, transaction } = require("../../db/query");

function toTransactionDto(row) {
  // Prefer offline collector UUID so the Flutter app can match local lots.
  const lotClientRef = row.lot_client_reference || null;
  const lotPublic = row.lot_public_id || row.lot_id;
  const lotIdForApp = lotClientRef || lotPublic;
  return {
    id: row.public_id,
    lotId: lotIdForApp,
    lot_id: lotIdForApp,
    clientReference: lotClientRef,
    client_reference: lotClientRef,
    lotPublicId: lotPublic,
    lot_public_id: lotPublic,
    lotNumber: row.lot_number,
    lot_number: row.lot_number,
    handoverId: row.handover_public_id,
    recyclerId: row.recycler_name || row.recycler_id,
    recycler_id: row.recycler_name || row.recycler_id,
    recyclerName: row.recycler_name,
    collectorId: row.collector_public_id,
    collectorName: row.collector_name,
    categoryName: row.category_name,
    category_name: row.category_name,
    weightKg: row.weight_kg === null ? 0 : Number(row.weight_kg),
    weight_kg: row.weight_kg === null ? 0 : Number(row.weight_kg),
    quotedPrice: row.quoted_price === null ? 0 : Number(row.quoted_price),
    quoted_price: row.quoted_price === null ? 0 : Number(row.quoted_price),
    finalPrice: row.final_price === null ? 0 : Number(row.final_price),
    final_price: row.final_price === null ? 0 : Number(row.final_price),
    paymentStatus: row.payment_status,
    payment_status: row.payment_status,
    handoverStatus: row.handover_status,
    handover_status: row.handover_status,
    createdAt: row.created_at,
    created_at: row.created_at,
  };
}

const TX_SELECT = `
  SELECT
    t.*,
    t.public_id,
    l.public_id AS lot_public_id,
    l.client_reference AS lot_client_reference,
    l.lot_number,
    h.public_id AS handover_public_id,
    u.public_id AS collector_public_id,
    u.full_name AS collector_name,
    rp.organisation_name AS recycler_name
  FROM transactions t
  LEFT JOIN lots l ON l.id = t.lot_id
  LEFT JOIN handovers h ON h.id = t.handover_id
  LEFT JOIN users u ON u.id = t.collector_id
  LEFT JOIN recycler_profiles rp ON rp.id = t.recycler_id
`;

async function listForCollector(collectorInternalId) {
  const rows = await queryRows(
    `${TX_SELECT}
     WHERE t.collector_id = $1
     ORDER BY t.created_at DESC
     LIMIT 100`,
    [collectorInternalId],
    { label: "transactions:listForCollector" }
  );
  return rows.map(toTransactionDto);
}

async function listForRecycler(recyclerProfileId) {
  const rows = await queryRows(
    `${TX_SELECT}
     WHERE t.recycler_id = $1
     ORDER BY t.created_at DESC
     LIMIT 100`,
    [recyclerProfileId],
    { label: "transactions:listForRecycler" }
  );
  return rows.map(toTransactionDto);
}

/**
 * Create a settlement row when a handover is confirmed (idempotent per lot).
 */
async function createFromHandover({
  lotInternalId,
  handoverInternalId,
  collectorId,
  recyclerId,
  categoryName,
  weightKg,
  quotedPrice,
  finalPrice,
  paymentStatus = "PENDING",
  handoverStatus = "CONFIRMED",
}) {
  return transaction(async (client) => {
    const existing = await queryOne(
      `SELECT * FROM transactions WHERE lot_id = $1 LIMIT 1`,
      [lotInternalId],
      { client, label: "transactions:findByLot" }
    );

    if (existing) {
      const full = await queryOne(
        `${TX_SELECT} WHERE t.id = $1`,
        [existing.id],
        { client, label: "transactions:reload" }
      );
      return { transaction: toTransactionDto(full), created: false };
    }

    const created = await queryOne(
      `INSERT INTO transactions (
         lot_id, handover_id, collector_id, recycler_id,
         category_name, weight_kg, quoted_price, final_price,
         payment_status, handover_status
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        lotInternalId,
        handoverInternalId,
        collectorId,
        recyclerId,
        categoryName,
        weightKg,
        quotedPrice,
        finalPrice,
        paymentStatus,
        handoverStatus,
      ],
      { client, label: "transactions:insert" }
    );

    const full = await queryOne(
      `${TX_SELECT} WHERE t.id = $1`,
      [created.id],
      { client, label: "transactions:reloadAfterInsert" }
    );

    return { transaction: toTransactionDto(full), created: true };
  });
}

module.exports = {
  listForCollector,
  listForRecycler,
  createFromHandover,
  toTransactionDto,
};
