/*
|--------------------------------------------------------------------------
| TRACEABILITY REPOSITORY
|--------------------------------------------------------------------------
| Reads the traceability timeline and projects it into the record shape the
| Recycler Dashboard already consumes.
|
| RESPONSE SHAPE CONTRACT (AGENTS.md section 5)
|
| GET /api/traceability      -> { success, count, records[] }
| GET /api/traceability/:id  -> { success, record }
|
| The dashboard's normalizeLot() requires, on every record:
|     id: string
|     material: string
|     collector: string
|     weight: number          (falls back to weightKg)
|     status: string          (must be one of the Title Cased labels)
|     createdAt: string
|   `location` falls back to `collectorLocation`.
|   A record missing any of these is silently dropped by the dashboard, so
|   the projection guarantees them rather than relying on a join being
|   populated.
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne } = require("../../db/query");
const {
  lotStatusLegacyLabel,
  toCanonicalLotStatus,
} = require("../../config/constants");

const SELECT_RECORDS = `
  SELECT
    l.public_id,
    l.lot_number,
    l.material_id,
    l.category_name,
    l.weight_kg,
    l.status,
    l.critical_mineral,
    l.ai_confidence,
    l.estimated_value,
    l.collection_address,
    l.condition,
    l.created_at,
    l.updated_at,
    l.completed_at,
    l.deleted_at,
    COALESCE(u.full_name, 'Unknown collector') AS collector_name,
    rp.organisation_name AS recycler_name,
    rp.address AS recycler_address
  FROM lots l
  LEFT JOIN users u ON u.id = l.collector_id
  LEFT JOIN recycler_profiles rp ON rp.id = l.recycler_id
`;

function toEvent(row) {
  return {
    id: row.sequence_no,
    sequenceNo: row.sequence_no,
    stage: row.stage,
    status: row.event_status,
    title: row.title,
    description: row.description,
    actor: row.actor,
    actorType: row.actor_type,
    location: row.location,
    lotStatusAtEvent: row.lot_status_at_event,
    timestamp: row.created_at,
  };
}

async function listEvents(lotId) {
  const rows = await queryRows(
    `SELECT *
     FROM traceability_events
     WHERE lot_id = $1
     ORDER BY sequence_no ASC`,
    [lotId],
    { label: "traceability:listEvents" }
  );

  return rows.map(toEvent);
}

/**
 * Load the event timelines for a whole page of lots in ONE query.
 *
 * Without this the list endpoint would issue 1 + N queries, which is the
 * classic N+1 problem and is noticeable once a recycler has a few hundred
 * lots.
 */
async function listEventsForLots(lotIds) {
  if (!Array.isArray(lotIds) || lotIds.length === 0) {
    return new Map();
  }

  const rows = await queryRows(
    `SELECT *
     FROM traceability_events
     WHERE lot_id = ANY($1::uuid[])
     ORDER BY lot_id, sequence_no ASC`,
    [lotIds],
    { label: "traceability:listEventsForLots" }
  );

  const grouped = new Map();

  for (const row of rows) {
    if (!grouped.has(row.lot_id)) {
      grouped.set(row.lot_id, []);
    }

    grouped.get(row.lot_id).push(toEvent(row));
  }

  return grouped;
}

/**
 * Build the traceability record for one lot row.
 *
 * Synchronous by design: the caller owns event loading, so it is obvious
 * whether a record triggers an extra query or not.
 *
 * @param {object} row     Row from SELECT_RECORDS
 * @param {Array}  events  Events already loaded for this lot
 * @param {Function} [deriveStatus] Injected by the service so this repository
 *                        stays free of presentation-stage rules
 */
function toRecord(row, events = [], deriveStatus) {
  if (!row) {
    return null;
  }

  const stage = currentStage(row.status);

  const timeline = events.map((event) => ({
    ...event,
    // Journey position is derived from the lot's current status, because the
    // event log is append-only and cannot be advanced in place.
    status: deriveStatus
      ? deriveStatus(event, row)
      : event.status,
  }));

  return {
    // --- Fields the dashboard requires ---
    id: row.lot_number || row.public_id,
    material: row.category_name || row.material_id || "Unknown",
    collector: row.collector_name || "Unknown collector",
    weight:
      row.weight_kg === null || row.weight_kg === undefined
        ? 0
        : Number(row.weight_kg),
    // Title Cased label: LotStatus in the dashboard is a union of these exact
    // strings, so a raw enum value would fail to typecheck and render blank.
    status: lotStatusLegacyLabel[row.status] || row.status,
    createdAt: row.created_at,

    // --- Detail fields ---
    lotId: row.public_id,
    lotNumber: row.lot_number,
    location: row.collection_address || "",
    collectorLocation: row.collection_address || "",
    currentLocation:
      row.status === "COMPLETED"
        ? row.recycler_name || "Recycling facility"
        : row.status === "HANDOVER"
          ? `In transit to ${row.recycler_name || "recycling facility"}`
          : row.collection_address || "Collector location",
    recycler: row.recycler_name || null,
    recyclerAddress: row.recycler_address || null,

    weightKg: row.weight_kg === null ? null : Number(row.weight_kg),

    aiConfidence:
      row.ai_confidence === null ? null : Number(row.ai_confidence),
    estimatedValue:
      row.estimated_value === null ? null : Number(row.estimated_value),
    criticalMineral: Boolean(row.critical_mineral),
    condition: row.condition || null,
    completedAt: row.completed_at,
    lastUpdated: row.updated_at,
    currentStage: stage,
    events: timeline,
  };
}

function currentStage(status) {
  switch (status) {
    case "PENDING":
      return "Verification";
    case "ACCEPTED":
      return "Handover";
    case "HANDOVER":
      return "Processing";
    case "COMPLETED":
      return "Completed";
    case "REJECTED":
      return "Verification";
    default:
      return "Collection";
  }
}

/**
 * Paginated record list with search and status filtering.
 */
async function list(
  { search = null, status = null, limit = 25, offset = 0 } = {},
  { deriveStatus } = {}
) {
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];

  if (status && status !== "All") {
    // The dashboard filters on the Title Cased label ("Pending"), the column
    // stores the canonical enum ("PENDING"). Without this normalisation the
    // filter would silently match nothing.
    const canonical = toCanonicalLotStatus(status);

    if (!canonical) {
      // An unknown status filter must not become a full-table scan.
      return { records: [], total: 0 };
    }

    params.push(canonical);
    conditions.push(`l.status = $${params.length}`);
  }

  if (search) {
    params.push(`%${String(search).toLowerCase()}%`);
    const placeholder = `$${params.length}`;

    conditions.push(`(
      LOWER(COALESCE(l.lot_number, '')) LIKE ${placeholder}
      OR LOWER(COALESCE(l.material_id, '')) LIKE ${placeholder}
      OR LOWER(COALESCE(l.category_name, '')) LIKE ${placeholder}
      OR LOWER(COALESCE(u.full_name, '')) LIKE ${placeholder}
    )`);
  }

  const where = conditions.join(" AND ");

  const rows = await queryRows(
    `${SELECT_RECORDS}
     WHERE ${where}
     ORDER BY l.created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, limit, offset],
    { label: "traceability:list" }
  );

  const countRow = await queryOne(
    `SELECT COUNT(*)::int AS total
     FROM lots l
     LEFT JOIN users u ON u.id = l.collector_id
     WHERE ${where}`,
    params,
    { label: "traceability:count" }
  );

  const eventsByLot = await listEventsForLots(rows.map((row) => row.id));

  const records = rows.map((row) =>
    toRecord(row, eventsByLot.get(row.id) ?? [], deriveStatus)
  );

  return { records, total: countRow?.total ?? 0 };
}

async function findByIdentifier(identifier, { deriveStatus } = {}) {
  const normalised = String(identifier);

  const row = await queryOne(
    `${SELECT_RECORDS}
     WHERE l.deleted_at IS NULL
       AND (l.lot_number = $1 OR l.public_id::text = $1)
     LIMIT 1`,
    [normalised],
    { label: "traceability:findByIdentifier" }
  );

  if (!row) {
    return null;
  }

  return toRecord(row, await listEvents(row.id), deriveStatus);
}

module.exports = {
  list,
  findByIdentifier,
  listEvents,
  listEventsForLots,
  toRecord,
  toEvent,
  currentStage,
};