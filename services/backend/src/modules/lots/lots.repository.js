/*
|--------------------------------------------------------------------------
| LOTS REPOSITORY
|--------------------------------------------------------------------------
| All SQL for lots. No business rules.
|
| Two identifiers coexist on purpose:
|   - id             internal UUID, never exposed
|   - public_id      client-facing UUID
|   - lot_number     human reference, e.g. KC-2026-0148 (the value the
|                    Recycler Dashboard and the collector app display)
|   - client_reference  device-generated UUID, the offline sync idempotency key
|
| Every list query filters out soft-deleted rows so a traceability record
| cannot disappear (AGENTS.md section 8).
|--------------------------------------------------------------------------
*/

const {
  queryRows,
  queryOne,
  insertOne,
  transaction,
} = require("../../db/query");
const { formatLotReference, currentYear, isUuid } = require("../../lib/ids");
const { lotStatusLegacyLabel } = require("../../config/constants");
const { NotFoundError } = require("../../lib/errors");

/**
 * Projection shared by every lot response. Aliases are deliberate: the
 * dashboard and the deployed collector APK read different key spellings, and
 * removing either would break a shipped client (AGENTS.md section 5).
 */
const LOT_PROJECTION = `
  l.id,
  l.public_id,
  l.client_reference,
  l.lot_number,
  l.collector_id,
  l.recycler_id,
  l.material_id,
  l.category_name,
  l.condition,
  l.weight_kg,
  l.status,
  l.sync_status,
  l.ai_confidence,
  l.critical_mineral,
  l.critical_mineral_reason,
  l.model_version,
  l.rule_version,
  l.estimated_value,
  l.estimated_min_value,
  l.estimated_max_value,
  l.estimated_currency,
  l.image_path,
  l.notes,
  l.collection_address,
  l.collection_latitude,
  l.collection_longitude,
  l.version,
  l.created_at,
  l.updated_at,
  l.completed_at,
  u.full_name AS collector_name,
  rp.organisation_name AS recycler_name
`;

const FROM_LOT = `
  FROM lots l
  LEFT JOIN users u ON u.id = l.collector_id
  LEFT JOIN recycler_profiles rp ON rp.id = l.recycler_id
`;

/**
 * Convert a row into the API shape.
 *
 * @param {object} row
 * @param {object} [options]
 * @param {boolean} [options.legacyAliases] Include camelCase aliases required
 *        by already-deployed clients.
 */
function toLotDto(row, { legacyAliases = true } = {}) {
  if (!row) {
    return null;
  }

  const lot = {
    // The PUBLIC identifier. This is what appears in URLs and in API
    // responses; the internal primary key is never exposed.
    id: row.public_id,
    lotNumber: row.lot_number,
    lot_number: row.lot_number,

    // The INTERNAL primary key, for writing child rows only.
    //
    // `id` above cannot be used for a foreign key: it is the public_id, and
    // traceability_events.lot_id / notifications.lot_id / ai_analyses.lot_id
    // all reference lots(id). Writing `lot.id` into one of them raises a
    // foreign key violation, so the internal key is carried explicitly.
    // Services must not send this to a client.
    internalId: row.id,

    collectorId: row.collector_id,
    collector: row.collector_name,

    recyclerId: row.recycler_id,
    recycler: row.recycler_name,

    materialId: row.material_id,
    material: row.material_id,
    categoryId: row.material_id,
    categoryName: row.category_name,

    weightKg: row.weight_kg === null ? null : Number(row.weight_kg),
    condition: row.condition,

    status: row.status,
    // Title-cased label the Recycler Dashboard matches on.
    statusLabel: lotStatusLegacyLabel[row.status] ?? row.status,

    syncStatus: row.sync_status,

    aiConfidence:
      row.ai_confidence === null ? null : Number(row.ai_confidence),
    criticalMineral: row.critical_mineral,
    criticalMineralReason: row.critical_mineral_reason,
    modelVersion: row.model_version,
    ruleVersion: row.rule_version,

    estimatedValue:
      row.estimated_value === null ? null : Number(row.estimated_value),
    estimatedMinValue:
      row.estimated_min_value === null ? null : Number(row.estimated_min_value),
    estimatedMaxValue:
      row.estimated_max_value === null ? null : Number(row.estimated_max_value),
    currency: row.estimated_currency,

    imagePath: row.image_path,
    notes: row.notes,

    location: row.collection_address,
    collectionAddress: row.collection_address,
    collectionLatitude:
      row.collection_latitude === null
        ? null
        : Number(row.collection_latitude),
    collectionLongitude:
      row.collection_longitude === null
        ? null
        : Number(row.collection_longitude),

    version: row.version,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at,
  };

  if (legacyAliases) {
    // Snake-case aliases for the collector app's local model mapping, which
    // reads created_at / updated_at / weight_kg.
    Object.assign(lot, {
      created_at: row.created_at,
      updated_at: row.updated_at,
      weight: lot.weightKg,
      weight_kg: lot.weightKg,
      ai_confidence: lot.aiConfidence,
      estimated_value: lot.estimatedValue,
      critical_mineral: lot.criticalMineral,
      sync_status: row.sync_status,
      category: lot.categoryName,
    });
  }

  return lot;
}

/*
|--------------------------------------------------------------------------
| LOT NUMBER ALLOCATION
|--------------------------------------------------------------------------
*/

async function nextLotNumber(client, now = new Date()) {
  const year = currentYear(now);

  // The sequence row is locked for the transaction, so two concurrent
  // uploads cannot be handed the same reference.
  const row = await client.query(
    `INSERT INTO lot_number_sequences (year, last_value)
     VALUES ($1, 1)
     ON CONFLICT (year)
     DO UPDATE SET last_value = lot_number_sequences.last_value + 1
     RETURNING last_value`,
    [year]
  );

  return formatLotReference(year, row.rows[0].last_value);
}

/*
|--------------------------------------------------------------------------
| CREATE
|--------------------------------------------------------------------------
*/

/**
 * Create a lot.
 *
 * When `clientReference` is supplied and already exists, the existing lot is
 * returned with `created: false`. That is what makes a retried offline sync
 * idempotent instead of duplicating a lot.
 */
async function create(lot, { client: providedClient } = {}) {
  const run = async (client) => {
    if (lot.clientReference) {
      const existing = await queryOne(
        `SELECT ${LOT_PROJECTION} ${FROM_LOT} WHERE l.client_reference = $1`,
        [lot.clientReference],
        { client, label: "lots:findByClientReference" }
      );

      if (existing) {
        return { lot: toLotDto(existing), created: false };
      }
    }

    const lotNumber = await nextLotNumber(client);

    const values = {
      client_reference: lot.clientReference ?? null,
      lot_number: lotNumber,
      collector_id: lot.collectorId ?? null,
      recycler_id: lot.recyclerId ?? null,
      material_id: lot.materialId ?? null,
      category_name: lot.categoryName ?? null,
      condition: lot.condition ?? null,
      weight_kg: lot.weightKg ?? null,
      status: lot.status ?? "PENDING",
      sync_status: lot.syncStatus ?? "SYNCED",
      ai_confidence: lot.aiConfidence ?? null,
      critical_mineral: lot.criticalMineral ?? null,
      critical_mineral_reason: lot.criticalMineralReason ?? null,
      model_version: lot.modelVersion ?? null,
      rule_version: lot.ruleVersion ?? null,
      estimated_value: lot.estimatedValue ?? null,
      estimated_min_value: lot.estimatedMinValue ?? null,
      estimated_max_value: lot.estimatedMaxValue ?? null,
      estimated_currency: lot.estimatedCurrency ?? "INR",
      estimated_at: lot.estimatedAt ?? null,
      image_path: lot.imagePath ?? null,
      notes: lot.notes ?? null,
      collection_address: lot.collectionAddress ?? null,
      collection_latitude: lot.collectionLatitude ?? null,
      collection_longitude: lot.collectionLongitude ?? null,
    };

    const columns = Object.keys(values);
    const placeholders = columns.map((_, index) => `$${index + 1}`);

    const row = await queryOne(
      `INSERT INTO lots (${columns.join(", ")})
       VALUES (${placeholders.join(", ")})
       RETURNING id`,
      columns.map((column) => values[column]),
      { client, label: "lots:create" }
    );

    const created = await queryOne(
      `SELECT ${LOT_PROJECTION} ${FROM_LOT} WHERE l.id = $1`,
      [row.id],
      { client, label: "lots:readCreated" }
    );

    return { lot: toLotDto(created), created: true };
  };

  if (providedClient) {
    return run(providedClient);
  }

  return transaction(run);
}

/*
|--------------------------------------------------------------------------
| READ
|--------------------------------------------------------------------------
*/

async function findByPublicId(publicId, { client } = {}) {
  const row = await queryOne(
    `SELECT ${LOT_PROJECTION} ${FROM_LOT}
     WHERE l.public_id = $1 AND l.deleted_at IS NULL`,
    [publicId],
    { client, label: "lots:findByPublicId" }
  );

  return toLotDto(row);
}

async function findByLotNumber(lotNumber, { client } = {}) {
  const row = await queryOne(
    `SELECT ${LOT_PROJECTION} ${FROM_LOT}
     WHERE l.lot_number = $1 AND l.deleted_at IS NULL`,
    [lotNumber],
    { client, label: "lots:findByLotNumber" }
  );

  return toLotDto(row);
}

/**
 * Resolve a client-supplied identifier that may be a public id or a lot
 * number, because the collector app and the dashboard use different ones.
 */
/**
 * Look up a lot by any identifier a client might hold: its public UUID, or
 * its human reference such as KC-2026-0148.
 *
 * The UUID query is only attempted when the value is actually shaped like a
 * UUID. Querying the uuid column with a lot number would raise 22P02 and fail
 * the whole request, so the lot-number fallback below would be unreachable.
 */
async function findByAnyIdentifier(identifier, options = {}) {
  if (isUuid(identifier)) {
    const byPublicId = await findByPublicId(identifier.trim(), options);

    if (byPublicId) {
      return byPublicId;
    }
  }

  return findByLotNumber(String(identifier).trim().toUpperCase(), options);
}

async function findById(id, { client } = {}) {
  const row = await queryOne(
    `SELECT ${LOT_PROJECTION} ${FROM_LOT} WHERE l.id = $1`,
    [id],
    { client, label: "lots:findById" }
  );

  return toLotDto(row);
}

/**
 * Look up a lot by the device-generated idempotency key. This is the lookup
 * that makes an offline sync retried after a timeout safe.
 */
async function findByClientReference(clientReference, { client } = {}) {
  const row = await queryOne(
    `SELECT ${LOT_PROJECTION} ${FROM_LOT}
     WHERE l.client_reference = $1 AND l.deleted_at IS NULL`,
    [clientReference],
    { client, label: "lots:findByClientReference" }
  );

  return toLotDto(row);
}

/**
 * Paginated, filtered list.
 *
 * @param {object} filters
 * @param {string} [filters.status]     Lot status
 * @param {string} [filters.collectorId] Internal collector user id
 * @param {string} [filters.recyclerId]  Internal recycler profile id
 * @param {string} [filters.materialId]
 * @param {boolean} [filters.criticalOnly]
 * @param {string} [filters.search]     Matches lot number, material or address
 * @param {string} [filters.since]      ISO timestamp, for incremental sync
 */
async function list(filters = {}, { limit = 25, offset = 0 } = {}) {
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];

  function addCondition(sql, value) {
    params.push(value);
    conditions.push(sql.replace("?", `$${params.length}`));
  }

  if (filters.status) {
    addCondition("l.status = ?", filters.status);
  }

  if (filters.collectorId) {
    addCondition("l.collector_id = ?", filters.collectorId);
  }

  if (filters.includeUnclaimedForRecycler && filters.recyclerId) {
    params.push(filters.recyclerId);
    conditions.push(
      `(l.recycler_id = $${params.length} OR l.recycler_id IS NULL)`
    );
  } else if (filters.recyclerId) {
    addCondition("l.recycler_id = ?", filters.recyclerId);
  }

  if (filters.materialId) {
    addCondition("l.material_id = ?", filters.materialId);
  }

  if (filters.criticalOnly) {
    conditions.push("l.critical_mineral = TRUE");
  }

  if (filters.search) {
    params.push(`%${String(filters.search).toLowerCase()}%`);
    const placeholder = `$${params.length}`;

    conditions.push(`(
      LOWER(l.lot_number) LIKE ${placeholder}
      OR LOWER(COALESCE(l.material_id, '')) LIKE ${placeholder}
      OR LOWER(COALESCE(l.category_name, '')) LIKE ${placeholder}
      OR LOWER(COALESCE(l.collection_address, '')) LIKE ${placeholder}
    )`);
  }

  if (filters.since) {
    addCondition("l.updated_at > ?", filters.since);
  }

  const where = conditions.join(" AND ");

  const countRow = await queryOne(
    `SELECT COUNT(*)::int AS total FROM lots l WHERE ${where}`,
    params,
    { label: "lots:count" }
  );

  const rows = await queryRows(
    `SELECT ${LOT_PROJECTION} ${FROM_LOT}
     WHERE ${where}
     ORDER BY l.created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, limit, offset],
    { label: "lots:list" }
  );

  return {
    lots: rows.map(toLotDto),
    total: countRow?.total ?? 0,
  };
}

/*
|--------------------------------------------------------------------------
| UPDATE
|--------------------------------------------------------------------------
*/

/**
 * Partial update with optimistic concurrency.
 *
 * `expectedVersion` guards the offline sync path: if the record changed on
 * the server while the device was offline, the caller is told rather than
 * silently overwriting.
 *
 * @param {string} internalId  lots.id — NOT the DTO's `id`, which is the
 *                            public_id. Passing the public id here would
 *                            match no row.
 * @returns {{lot: object|null, conflict: boolean}}
 */
async function update(
  internalId,
  patch,
  { expectedVersion = null, client: providedClient } = {}
) {
  const assignments = [];
  const params = [internalId];

  const columnMap = {
    materialId: "material_id",
    categoryName: "category_name",
    condition: "condition",
    weightKg: "weight_kg",
    status: "status",
    syncStatus: "sync_status",
    aiConfidence: "ai_confidence",
    criticalMineral: "critical_mineral",
    criticalMineralReason: "critical_mineral_reason",
    modelVersion: "model_version",
    ruleVersion: "rule_version",
    estimatedValue: "estimated_value",
    estimatedMinValue: "estimated_min_value",
    estimatedMaxValue: "estimated_max_value",
    estimatedAt: "estimated_at",
    imagePath: "image_path",
    notes: "notes",
    collectionAddress: "collection_address",
    collectionLatitude: "collection_latitude",
    collectionLongitude: "collection_longitude",
    recyclerId: "recycler_id",
    rejectedAt: "rejected_at",
    completedAt: "completed_at",
  };

  for (const [key, column] of Object.entries(columnMap)) {
    if (Object.prototype.hasOwnProperty.call(patch, key)) {
      params.push(patch[key]);
      assignments.push(`${column} = $${params.length}`);
    }
  }

  if (assignments.length === 0) {
    const unchanged = await findById(internalId, { client: providedClient });

    requireFoundRow(unchanged, internalId);

    return { lot: unchanged, conflict: false };
  }

  // Bumping version is what makes the next expectedVersion check meaningful.
  assignments.push("version = version + 1");

  const versionCondition = expectedVersion === null
    ? ""
    : ` AND version = $${params.push(expectedVersion)}`;

  const row = await queryOne(
    `UPDATE lots
     SET ${assignments.join(", ")}
     WHERE id = $1 AND deleted_at IS NULL${versionCondition}
     RETURNING id, version`,
    params,
    { client: providedClient, label: "lots:update" }
  );

  if (!row) {
    // Either the lot does not exist, or the version did not match.
    const current = await findById(internalId, { client: providedClient });

    // A missing row here is almost always the public id being passed where
    // the internal id was required. Returning { lot: null } would let that
    // mistake propagate as a silent no-op, so it is raised instead.
    requireFoundRow(current, internalId);

    return { lot: current, conflict: true };
  }

  const updated = await findById(internalId, { client: providedClient });

  return { lot: updated, conflict: false };
}

/**
 * Raise when a write targeted no row.
 *
 * The overwhelmingly likely cause is the public/internal id mix-up
 * described above; a silent no-op there is far more damaging than an
 * exception.
 */
function requireFoundRow(lot, internalId) {
  if (lot === null) {
    throw new NotFoundError(`No lot with internal id ${internalId}`, {
      internalId,
    });
  }
}

/**
 * Atomically assign an unclaimed lot to a recycler and move it to ACCEPTED.
 *
 * The `recycler_id IS NULL` predicate is the whole point: two recyclers
 * accepting the same lot at the same moment produce two UPDATE attempts, and
 * only one matches the predicate. The loser sees an empty RETURNING and gets
 * a conflict, instead of both believing they own the lot.
 *
 * @returns {{lot: object|null, conflict: boolean}}
 */
async function claimForRecycler(internalId, recyclerId, nextStatus) {
  const row = await queryOne(
    `UPDATE lots
     SET recycler_id = $2,
         status = $3,
         version = version + 1
     WHERE id = $1
       AND recycler_id IS NULL
       AND deleted_at IS NULL
     RETURNING id`,
    [internalId, recyclerId, nextStatus],
    { label: "lots:claimForRecycler" }
  );

  if (!row) {
    return { lot: null, conflict: true };
  }

  return { lot: await findById(internalId), conflict: false };
}

/**
 * Soft delete. A traceability record is never hard deleted.
 */
async function softDelete(internalId) {
  const row = await queryOne(
    `UPDATE lots
     SET deleted_at = NOW(), version = version + 1
     WHERE id = $1 AND deleted_at IS NULL
     RETURNING id`,
    [internalId],
    { label: "lots:softDelete" }
  );

  return row !== null;
}

async function setStatus(internalId, status, { client } = {}) {
  // Only COMPLETED stamps completed_at; every other transition must leave a
  // previously stamped value alone rather than clearing it.
  const patch = { status };

  if (status === "COMPLETED") {
    patch.completedAt = new Date();
  }

  const { lot } = await update(internalId, patch, { client });

  return lot;
}

module.exports = {
  LOT_PROJECTION,
  FROM_LOT,
  toLotDto,
  create,
  findByPublicId,
  findByLotNumber,
  findByAnyIdentifier,
  findById,
  findByClientReference,
  list,
  update,
  claimForRecycler,
  softDelete,
  setStatus,
  nextLotNumber,
};