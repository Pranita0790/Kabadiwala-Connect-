/*
|--------------------------------------------------------------------------
| HANDOVERS SERVICE
|--------------------------------------------------------------------------
*/

const crypto = require("crypto");
const repository = require("./handovers.repository");
const transactionsRepository = require("../transactions/transactions.repository");
const lotsRepository = require("../lots/lots.repository");
const lotsService = require("../lots/lots.service");
const {
  ValidationError,
  NotFoundError,
  AuthorizationError,
} = require("../../lib/errors");
const { userRole, lotStatus } = require("../../config/constants");

function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(value || "")
  );
}

async function ensureLotForHandover(input, user, lotIdentifier) {
  let lot = await lotsRepository.findByAnyIdentifier(lotIdentifier);
  if (lot) {
    return lot;
  }

  // Offline devices often sync handovers before POST /api/lots succeeds.
  // Auto-create an idempotent lot so the recycler web dashboard can see it.
  // Allow COLLECTOR, RECYCLER (demo/same device), and ADMIN.
  if (
    user.role !== userRole.COLLECTOR &&
    user.role !== userRole.RECYCLER &&
    user.role !== userRole.ADMIN
  ) {
    throw new NotFoundError(`Lot "${lotIdentifier}" not found`);
  }

  const clientReference = isUuid(lotIdentifier) ? lotIdentifier : null;
  const materialCategory =
    input.materialCategory || input.material_category || "mixed";
  const weightKg = Number(input.weightKg ?? input.weight_kg ?? 0);
  const agreedAmount = Number(input.agreedAmount ?? input.agreed_amount ?? 0);

  const created = await lotsService.create(
    {
      clientReference,
      materialId: null,
      categoryName: materialCategory,
      condition: "Scrap",
      weightKg: Number.isFinite(weightKg) ? weightKg : 0,
      notes: "Auto-created from handover sync",
      estimatedValue: Number.isFinite(agreedAmount) ? agreedAmount : null,
    },
    user
  );

  lot = created.lot;
  if (!lot) {
    throw new NotFoundError(`Lot "${lotIdentifier}" not found`);
  }
  return lot;
}

async function assignRecyclerToLot(lot, recyclerId) {
  if (!recyclerId || !lot?.internalId) {
    return lot;
  }
  if (lot.recyclerId === recyclerId) {
    return lot;
  }

  try {
    const { lot: updated } = await lotsRepository.update(lot.internalId, {
      recyclerId,
    });
    return updated || lot;
  } catch {
    return lot;
  }
}

async function advanceLotTowardHandover(lot, user) {
  // Status machine: PENDING -> ACCEPTED -> HANDOVER (no skipping).
  let current = lot;
  try {
    if (current.status === lotStatus.PENDING) {
      const accepted = await lotsService.changeStatus(
        current.id,
        lotStatus.ACCEPTED,
        user,
        { note: "Auto-accepted for handover sync" }
      );
      current = accepted?.lot || current;
    }
  } catch {
    // May already be accepted / claimed by another path.
  }

  try {
    const fresh = await lotsRepository.findByAnyIdentifier(current.id);
    current = fresh || current;
    if (current.status === lotStatus.ACCEPTED) {
      await lotsService.changeStatus(current.id, lotStatus.HANDOVER, user, {
        note: "Handover created",
      });
    }
  } catch {
    // Handover row still exists even if status transition is refused.
  }
}

async function create(input, user) {
  const lotIdentifier = input.lotId || input.lot_id;
  if (!lotIdentifier) {
    throw new ValidationError("lotId is required");
  }

  let lot = await ensureLotForHandover(input, user, lotIdentifier);

  lotsService.assertCanView(lot, user);

  const clientReference =
    input.clientReference ||
    (isUuid(input.id) ? input.id : null) ||
    crypto.randomUUID();

  let recyclerId = lot.recyclerId;
  if (user.role === userRole.RECYCLER && user.recyclerId) {
    recyclerId = user.recyclerId;
  } else if (input.recyclerId || input.recycler_id) {
    // Collector may pass a recycler profile id when known; otherwise leave null
    // until a recycler confirms.
    const candidate = input.recyclerId || input.recycler_id;
    if (isUuid(candidate)) {
      recyclerId = recyclerId || candidate;
    }
  }

  // Bind the lot to ORG (or whichever recycler was selected) so GET /api/lots
  // on the recycler dashboard returns it immediately.
  if (recyclerId) {
    lot = await assignRecyclerToLot(lot, recyclerId);
  }

  const { handover, created } = await repository.create({
    clientReference,
    lotInternalId: lot.internalId,
    collectorId: lot.collectorId,
    recyclerId,
    materialCategory:
      input.materialCategory ||
      input.material_category ||
      lot.categoryName ||
      lot.materialId,
    weightKg: Number(input.weightKg ?? input.weight_kg ?? lot.weightKg ?? 0),
    agreedAmount: Number(
      input.agreedAmount ?? input.agreed_amount ?? lot.estimatedValue ?? 0
    ),
    qrToken: input.qrPayload || input.qr_payload || clientReference,
  });

  if (created) {
    await advanceLotTowardHandover(lot, user);
  }

  return { handover, created };
}

async function confirm(handoverId, user, options = {}) {
  const raw = await repository.findRawByPublicId(handoverId);
  if (!raw) {
    throw new NotFoundError(`Handover "${handoverId}" not found`);
  }

  const lot = await lotsRepository.findByAnyIdentifier(raw.lot_public_id);
  if (!lot) {
    throw new NotFoundError("Linked lot not found");
  }

  const isCollector = user.role === userRole.COLLECTOR && lot.collectorId === user.id;
  const isRecycler =
    user.role === userRole.RECYCLER &&
    user.recyclerId &&
    (!raw.recycler_id || raw.recycler_id === user.recyclerId);
  const isAdmin = user.role === userRole.ADMIN;

  if (!isCollector && !isRecycler && !isAdmin) {
    throw new AuthorizationError("You cannot confirm this handover");
  }

  // Demo / single-device confirm stamps both sides so a transactions row is
  // created without a second actor. Allowed for the lot owner, assigned
  // recycler, or admin (collector app often uses the ORG recycler JWT).
  const completeBoth =
    Boolean(options.completeBoth || options.demoComplete) &&
    (isCollector || isRecycler || isAdmin);

  // Dual confirmation: each party stamps their side; admin / demo stamps both.
  const handover = await repository.markConfirmed(raw.id, {
    byCollector: isCollector || isAdmin || completeBoth,
    byRecycler: isRecycler || isAdmin || completeBoth,
  });

  if (handover?.status === "CONFIRMED") {
    const amount = Number(handover.agreedAmount || lot.estimatedValue || 0);

    await transactionsRepository.createFromHandover({
      lotInternalId: lot.internalId,
      handoverInternalId: raw.id,
      collectorId: lot.collectorId,
      recyclerId: handover.recyclerId || user.recyclerId || null,
      categoryName: handover.materialCategory || lot.categoryName,
      weightKg: handover.weightKg || lot.weightKg,
      quotedPrice: amount,
      finalPrice: amount,
      paymentStatus: "PAID",
      handoverStatus: "CONFIRMED",
    });

    if (lot.status !== lotStatus.COMPLETED) {
      try {
        await lotsService.changeStatus(lot.id, lotStatus.COMPLETED, user, {
          note: "Handover confirmed",
        });
      } catch {
        // If transition requires intermediate states, leave lot as-is.
      }
    }
  }

  return handover;
}

module.exports = { create, confirm };
