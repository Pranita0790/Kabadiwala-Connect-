/*
|--------------------------------------------------------------------------
| DOMAIN CONSTANTS
|--------------------------------------------------------------------------
| Values that are part of the business domain rather than configuration.
|
| Status vocabularies are NOT defined here. They are loaded from
| packages/shared/contracts/enums.json so the backend, the collector app and
| the recycler dashboard cannot drift apart.
|
| Reference: docs/api/api-contract.md
|--------------------------------------------------------------------------
*/

const enums = require("../../../../packages/shared/contracts/enums.json");

/*
|--------------------------------------------------------------------------
| RE-EXPORTED SHARED ENUMS
|--------------------------------------------------------------------------
*/

const userRole = Object.freeze(enums.userRole);
const lotStatus = Object.freeze(enums.lotStatus);
const lotStatusLegacyLabel = Object.freeze(enums.lotStatusLegacyLabel);
const syncStatus = Object.freeze(enums.syncStatus);
const handoverStatus = Object.freeze(enums.handoverStatus);
const paymentStatus = Object.freeze(enums.paymentStatus);
const notificationType = Object.freeze(enums.notificationType);
const materialClass = Object.freeze(enums.materialClass);
const materialCondition = Object.freeze(enums.materialCondition);
const traceabilityStage = Object.freeze(enums.traceabilityStage);
const traceabilityEventStatus = Object.freeze(enums.traceabilityEventStatus);
const deployedModel = Object.freeze(enums.deployedModel);

/*
|--------------------------------------------------------------------------
| LOT STATUS MACHINE
|--------------------------------------------------------------------------
| Guarding transitions in one place is what keeps the traceability timeline
| honest. The Recycler Dashboard and the Collector App both drive these
| transitions, so the rules live server-side, not in either client.
|--------------------------------------------------------------------------
*/

const LOT_STATUS_TRANSITIONS = Object.freeze({
  PENDING: ["ACCEPTED", "REJECTED"],
  ACCEPTED: ["HANDOVER", "REJECTED"],
  HANDOVER: ["COMPLETED", "REJECTED"],
  REJECTED: [],
  COMPLETED: [],
});

function canTransitionLotStatus(from, to) {
  const allowed = LOT_STATUS_TRANSITIONS[from];

  if (!allowed) {
    return false;
  }

  return allowed.includes(to);
}

/**
 * Accept a lot status in either the canonical enum form ("PENDING") or the
 * Title Cased label the Recycler Dashboard sends ("Pending") and return the
 * canonical form, or null if it matches neither.
 *
 * Both forms reach the API: the dashboard filters and filters by label, while
 * the collector app and the database use the enum.
 */
function toCanonicalLotStatus(value) {
  if (typeof value !== "string") {
    return null;
  }

  const candidate = value.trim();

  if (Object.values(lotStatus).includes(candidate)) {
    return candidate;
  }

  const match = Object.entries(lotStatusLegacyLabel).find(
    ([, label]) => label.toLowerCase() === candidate.toLowerCase()
  );

  return match ? match[0] : null;
}

/*
|--------------------------------------------------------------------------
| TRACEABILITY STAGE MACHINE
|--------------------------------------------------------------------------
| The stage a lot has reached is derived from its status, never stored
| independently, so the two can never disagree.
|--------------------------------------------------------------------------
*/

const LOT_STATUS_TO_STAGE = Object.freeze({
  PENDING: traceabilityStage.VERIFICATION,
  ACCEPTED: traceabilityStage.HANDOVER,
  HANDOVER: traceabilityStage.PROCESSING,
  COMPLETED: traceabilityStage.COMPLETED,
  REJECTED: traceabilityStage.VERIFICATION,
});

/*
|--------------------------------------------------------------------------
| MATERIAL IDENTIFIERS
|--------------------------------------------------------------------------
*/

const MATERIAL_ID_BY_CLASS = Object.freeze({
  pcb: "pcb",
  battery: "battery",
  crt: "crt",
  lcd_panel: "lcd-panel",
  cable: "cable",
  motor: "motor",
  magnet_bearing_assembly: "magnet-bearing-assembly",
  mixed_plastics: "mixed-plastics",
});

const LOT_ID_PREFIX = "KC";

/*
|--------------------------------------------------------------------------
| SYNC
|--------------------------------------------------------------------------
*/

/**
 * Offline-first sync: the collector app assigns a client-side UUID, and the
 * backend keeps it as the idempotency key so a retried batch from a flaky
 * network cannot create duplicate lots.
 */
const SYNC_BATCH_MAX_ITEMS = 50;

const SYNC_CONFLICT_STRATEGY = Object.freeze({
  LAST_WRITE_WINS: "LAST_WRITE_WINS",
  BACKEND_WINS: "BACKEND_WINS",
  CLIENT_WINS: "CLIENT_WINS",
});

/*
|--------------------------------------------------------------------------
| AI INFERENCE WORDING
|--------------------------------------------------------------------------
| AI output is an inference, not proof of elemental composition
| (AGENTS.md section 7). These strings are used in user-facing messages.
|--------------------------------------------------------------------------
*/

const CRITICAL_MINERAL_POTENTIAL_MESSAGE =
  "Potential critical mineral detected — rule-based inference, not laboratory analysis.";

const AI_DISCLAIMER =
  "Indicative estimate based on image-based inference and current rate card. Not a guaranteed market price.";

module.exports = {
  enums,
  userRole,
  lotStatus,
  lotStatusLegacyLabel,
  syncStatus,
  handoverStatus,
  paymentStatus,
  notificationType,
  materialClass,
  materialCondition,
  traceabilityStage,
  traceabilityEventStatus,
  deployedModel,
  LOT_STATUS_TRANSITIONS,
  canTransitionLotStatus,
  toCanonicalLotStatus,
  LOT_STATUS_TO_STAGE,
  MATERIAL_ID_BY_CLASS,
  LOT_ID_PREFIX,
  SYNC_BATCH_MAX_ITEMS,
  SYNC_CONFLICT_STRATEGY,
  CRITICAL_MINERAL_POTENTIAL_MESSAGE,
  AI_DISCLAIMER,
};
