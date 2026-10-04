/*
|--------------------------------------------------------------------------
| HANDOVERS REPOSITORY
|--------------------------------------------------------------------------
*/

const crypto = require("crypto");
const { queryOne, queryRows, insertOne } = require("../../db/query");

function hashToken(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function toHandoverDto(row) {
  return {
    id: row.public_id,
    clientReference: row.client_reference,
    lotId: row.lot_public_id,
    lot_id: row.lot_public_id,
    lotInternalId: row.lot_id,
    collectorId: row.collector_id,
    recyclerId: row.recycler_id,
    recycler_id: row.recycler_id,
    recyclerName: row.recycler_name,
    recycler_name: row.recycler_name,
    materialCategory: row.material_category,
    material_category: row.material_category,
    weightKg: row.weight_kg === null ? 0 : Number(row.weight_kg),
    weight_kg: row.weight_kg === null ? 0 : Number(row.weight_kg),
    agreedAmount: row.agreed_amount === null ? 0 : Number(row.agreed_amount),
    agreed_amount: row.agreed_amount === null ? 0 : Number(row.agreed_amount),
    status: row.status,
    qrPayload: JSON.stringify({
      handover_id: row.public_id,
      lot_id: row.lot_public_id,
      version: row.qr_payload_version || 1,
      type: "E_WASTE_HANDOVER",
    }),
    qr_payload: JSON.stringify({
      handover_id: row.public_id,
      lot_id: row.lot_public_id,
      version: row.qr_payload_version || 1,
      type: "E_WASTE_HANDOVER",
    }),
    createdAt: row.created_at,
    created_at: row.created_at,
    confirmedAt: row.confirmed_at,
    confirmed_at: row.confirmed_at,
    syncStatus: row.sync_status,
    sync_status: row.sync_status,
    retryCount: row.retry_count || 0,
    retry_count: row.retry_count || 0,
  };
}

const HANDOVER_SELECT = `
  SELECT
    h.*,
    l.public_id AS lot_public_id,
    rp.organisation_name AS recycler_name
  FROM handovers h
  JOIN lots l ON l.id = h.lot_id
  LEFT JOIN recycler_profiles rp ON rp.id = h.recycler_id
`;

async function findByPublicId(publicId) {
  const row = await queryOne(
    `${HANDOVER_SELECT} WHERE h.public_id = $1`,
    [publicId],
    { label: "handovers:findByPublicId" }
  );
  return row ? toHandoverDto(row) : null;
}

async function findByClientReference(clientReference) {
  const row = await queryOne(
    `${HANDOVER_SELECT} WHERE h.client_reference = $1`,
    [clientReference],
    { label: "handovers:findByClientReference" }
  );
  return row ? toHandoverDto(row) : null;
}

async function findRawByPublicId(publicId) {
  const byPublic = await queryOne(
    `${HANDOVER_SELECT} WHERE h.public_id = $1`,
    [publicId],
    { label: "handovers:findRawByPublicId" }
  );
  if (byPublic) {
    return byPublic;
  }

  // Collector confirms with its local handover UUID (stored as client_reference).
  const byClient = await queryOne(
    `${HANDOVER_SELECT} WHERE h.client_reference = $1`,
    [publicId],
    { label: "handovers:findRawByClientReference" }
  );
  if (byClient) {
    return byClient;
  }

  // Recycler website confirms with the lot public id / lot number.
  // Cast all sides to text — mixing uuid = text makes Postgres throw 42883.
  return queryOne(
    `${HANDOVER_SELECT}
     WHERE l.public_id::text = $1::text
        OR l.lot_number = $1::text
        OR COALESCE(l.client_reference::text, '') = $1::text
     ORDER BY h.created_at DESC
     LIMIT 1`,
    [String(publicId)],
    { label: "handovers:findRawByLotIdentifier" }
  );
}

async function findRawLatestByLotInternalId(lotInternalId) {
  return queryOne(
    `${HANDOVER_SELECT} WHERE h.lot_id = $1 ORDER BY h.created_at DESC LIMIT 1`,
    [lotInternalId],
    { label: "handovers:findRawByLot" }
  );
}

async function create({
  clientReference,
  lotInternalId,
  collectorId,
  recyclerId,
  materialCategory,
  weightKg,
  agreedAmount,
  qrToken,
}) {
  if (clientReference) {
    const existing = await findByClientReference(clientReference);
    if (existing) {
      return { handover: existing, created: false };
    }
  }

  const row = await insertOne(
    "handovers",
    {
      client_reference: clientReference || null,
      lot_id: lotInternalId,
      collector_id: collectorId || null,
      recycler_id: recyclerId || null,
      material_category: materialCategory || null,
      weight_kg: weightKg ?? null,
      agreed_amount: agreedAmount ?? null,
      qr_token_hash: qrToken ? hashToken(qrToken) : hashToken(clientReference || crypto.randomUUID()),
      status: "PENDING_CONFIRMATION",
      sync_status: "SYNCED",
    },
    { label: "handovers:insert" }
  );

  const full = await findRawByPublicId(row.public_id);
  return { handover: toHandoverDto(full), created: true };
}

async function markConfirmed(internalId, { byCollector, byRecycler }) {
  const row = await queryOne(
    `UPDATE handovers
     SET
       collector_confirmed_at = CASE
         WHEN $2::boolean THEN COALESCE(collector_confirmed_at, NOW())
         ELSE collector_confirmed_at
       END,
       recycler_confirmed_at = CASE
         WHEN $3::boolean THEN COALESCE(recycler_confirmed_at, NOW())
         ELSE recycler_confirmed_at
       END,
       status = CASE
         WHEN (
           (CASE WHEN $2::boolean THEN TRUE ELSE collector_confirmed_at IS NOT NULL END)
           AND
           (CASE WHEN $3::boolean THEN TRUE ELSE recycler_confirmed_at IS NOT NULL END)
         ) THEN 'CONFIRMED'
         ELSE status
       END,
       confirmed_at = CASE
         WHEN (
           (CASE WHEN $2::boolean THEN TRUE ELSE collector_confirmed_at IS NOT NULL END)
           AND
           (CASE WHEN $3::boolean THEN TRUE ELSE recycler_confirmed_at IS NOT NULL END)
         ) THEN COALESCE(confirmed_at, NOW())
         ELSE confirmed_at
       END,
       updated_at = NOW()
     WHERE id = $1
     RETURNING public_id`,
    [internalId, Boolean(byCollector), Boolean(byRecycler)],
    { label: "handovers:markConfirmed" }
  );

  if (!row) {
    return null;
  }

  return findByPublicId(row.public_id);
}

async function listForRecycler(recyclerProfileId) {
  const rows = await queryRows(
    `${HANDOVER_SELECT}
     WHERE h.recycler_id = $1
     ORDER BY h.created_at DESC
     LIMIT 100`,
    [recyclerProfileId],
    { label: "handovers:listForRecycler" }
  );
  return rows.map(toHandoverDto);
}

module.exports = {
  create,
  findByPublicId,
  findByClientReference,
  findRawByPublicId,
  findRawLatestByLotInternalId,
  markConfirmed,
  listForRecycler,
  toHandoverDto,
  hashToken,
};
