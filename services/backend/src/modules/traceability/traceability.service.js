/*
|--------------------------------------------------------------------------
| TRACEABILITY SERVICE
|--------------------------------------------------------------------------
| Owns the traceability timeline.
|
| Design decision: the timeline is APPENDED TO by domain transitions, never
| written directly by a route. A caller cannot fabricate a "Processing
| completed" event for a lot that was never processed, because there is no
| endpoint that accepts an event body.
|
| Every event is inserted in the same transaction as the lot status change
| that caused it (AGENTS.md section 4: traceability records belong to the
| backend). If the event insert fails, the status change fails with it.
|--------------------------------------------------------------------------
*/

const repository = require("./traceability.repository");
const { insertOne, queryOne } = require("../../db/query");
const {
  lotStatus,
  traceabilityStage,
  traceabilityEventStatus,
} = require("../../config/constants");
const { NotFoundError } = require("../../lib/errors");

/*
|--------------------------------------------------------------------------
| STATUS → STAGE MAPPING
|--------------------------------------------------------------------------
*/

const STAGE_FOR_STATUS = Object.freeze({
  [lotStatus.PENDING]: traceabilityStage.VERIFICATION,
  [lotStatus.ACCEPTED]: traceabilityStage.HANDOVER,
  [lotStatus.REJECTED]: traceabilityStage.VERIFICATION,
  [lotStatus.HANDOVER]: traceabilityStage.PROCESSING,
  [lotStatus.COMPLETED]: traceabilityStage.COMPLETED,
});

const TITLE_FOR_STATUS = Object.freeze({
  [lotStatus.PENDING]: "Awaiting recycler review",
  [lotStatus.ACCEPTED]: "Lot accepted",
  [lotStatus.REJECTED]: "Lot rejected",
  [lotStatus.HANDOVER]: "Handed over to facility",
  [lotStatus.COMPLETED]: "Processing and settlement complete",
});

function stageForStatus(status) {
  return STAGE_FOR_STATUS[status] ?? traceabilityStage.VERIFICATION;
}

function titleForStatus(status) {
  return TITLE_FOR_STATUS[status] ?? "Status updated";
}

/*
|--------------------------------------------------------------------------
| WRITE
|--------------------------------------------------------------------------
*/

/**
 * Resolve the internal lots primary key from a lot DTO.
 *
 * The DTO's `id` is the PUBLIC id, which is what belongs in URLs and API
 * responses; `traceability_events.lot_id` references the internal key. Using
 * `lot.id` here raises a foreign key violation, so the internal key is
 * required and its absence is treated as a programming error rather than
 * being papered over with a lookup.
 */
function requireInternalId(lot) {
  if (!lot?.internalId) {
    throw new Error(
      "traceability.recordEvent requires a lot DTO carrying internalId"
    );
  }

  return lot.internalId;
}

/**
 * Append one traceability event.
 *
 * The stored `event_status` is 'completed': the event happened, so that is
 * what the row records. Journey position ("current"/"pending") is derived at
 * read time by deriveEventStatus(), because the log cannot be updated.
 *
 * @param {object} lot    Lot DTO (must carry internalId and lotNumber)
 * @param {object} event  Stage/title/description/actor
 * @param {object} [opts] { client } — pass a transaction client so the event
 *                          commits atomically with the status change
 */
async function recordEvent(lot, event, { client } = {}) {
  const lotId = requireInternalId(lot);
  const sequenceNo = await nextSequenceNo(lotId, client);

  return insertOne(
    "traceability_events",
    {
      lot_id: lotId,
      sequence_no: sequenceNo,
      stage: event.stage,
      event_status: traceabilityEventStatus.COMPLETED,
      title: event.title,
      description: event.description ?? null,
      actor: event.actor ?? null,
      actor_type: event.actorType ?? null,
      // The lot status at the moment the event was recorded, so the timeline
      // stays readable even if the lot's status later changes.
      lot_status_at_event: event.lotStatusAtEvent ?? lot.status ?? null,
      location: event.location ?? null,
    },
    { client, label: "traceability:recordEvent" }
  );
}

/**
 * Sequence numbers are per-lot and gapless so the timeline reads as a
 * sequence rather than a set of unordered timestamps.
 *
 * The advisory lock serialises concurrent appends to the same lot; without
 * it two simultaneous transitions could take the same sequence_no.
 */
async function nextSequenceNo(lotId, client) {
  if (client) {
    await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
      `traceability:${lotId}`,
    ]);

    const row = await client.query(
      "SELECT COALESCE(MAX(sequence_no), 0) + 1 AS next FROM traceability_events WHERE lot_id = $1",
      [lotId]
    );

    return row.rows[0].next;
  }

  // Outside a transaction (e.g. seeding), fall back to the same computation
  // without the lock.
  const row = await queryOne(
    "SELECT COALESCE(MAX(sequence_no), 0) + 1 AS next FROM traceability_events WHERE lot_id = $1",
    [lotId],
    { label: "traceability:nextSequenceNo" }
  );

  return row.next;
}

/**
 * Append an event inside a transaction. Used by callers that are already
 * inside one.
 */
async function recordEventInTransaction(client, lot, event) {
  return recordEvent(lot, event, { client });
}

/*
|--------------------------------------------------------------------------
| READ
|--------------------------------------------------------------------------
*/

/**
 * Derive each event's DISPLAY status from the lot's current status.
 *
 * The event log is append-only (migration 006 installs a trigger that blocks
 * UPDATE and DELETE), so an event's stored status is fixed at insert time and
 * cannot be "advanced" when the lot moves on. The journey position is
 * therefore computed here, at read time, from the lot's current stage:
 *
 *   stage before current stage -> completed
 *   stage equal to current     -> current
 *   stage after current stage  -> pending
 *
 * This is also what the Recycler Dashboard's JourneyStatus type accepts:
 * exactly "completed" | "current" | "pending" and nothing else
 * (apps/recycler-dashboard/src/pages/Traceability.tsx).
 */
function deriveEventStatus(event, lot) {
  const order = [
    traceabilityStage.COLLECTION,
    traceabilityStage.VERIFICATION,
    traceabilityStage.HANDOVER,
    traceabilityStage.PROCESSING,
    traceabilityStage.COMPLETED,
  ];

  const currentIndex = order.indexOf(stageForStatus(lot.status));
  const eventIndex = order.indexOf(event.stage);

  if (eventIndex === -1 || currentIndex === -1) {
    return traceabilityEventStatus.PENDING;
  }

  if (eventIndex < currentIndex) {
    return traceabilityEventStatus.COMPLETED;
  }

  if (eventIndex === currentIndex) {
    return traceabilityEventStatus.CURRENT;
  }

  return traceabilityEventStatus.PENDING;
}

/**
 * List traceability records for the dashboard.
 *
 * This endpoint is ADMIN/RECYCLER-only: a traceability record exposes another
 * party's full name and collection address, which a collector must not be
 * able to enumerate. Collectors see their own lots via /api/lots.
 */
async function list(filters) {
  return repository.list(filters, { deriveStatus: deriveEventStatus });
}

async function getByIdentifier(identifier, user) {
  const record = await repository.findByIdentifier(identifier, {
    deriveStatus: deriveEventStatus,
  });

  if (!record) {
    throw new NotFoundError(`Traceability record for "${identifier}" not found`, {
      lotId: identifier,
    });
  }

  return record;
}

async function timeline(lotId) {
  return repository.listEvents(lotId);
}

module.exports = {
  recordEvent,
  recordEventInTransaction,
  deriveEventStatus,
  stageForStatus,
  titleForStatus,
  list,
  getByIdentifier,
  timeline,
};