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

async function create(input, user) {
  const lotIdentifier = input.lotId || input.lot_id;
  if (!lotIdentifier) {
    throw new ValidationError("lotId is required");
  }

  const lot = await lotsRepository.findByAnyIdentifier(lotIdentifier);
  if (!lot) {
    throw new NotFoundError(`Lot "${lotIdentifier}" not found`);
  }

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

  // Starting a handover moves the lot into HANDOVER when it is already accepted
  // (or still pending for demo flows where accept was skipped).
  if (
    created &&
    (lot.status === lotStatus.ACCEPTED || lot.status === lotStatus.PENDING)
  ) {
    try {
      await lotsService.changeStatus(lot.id, lotStatus.HANDOVER, user, {
        note: "Handover created",
      });
    } catch {
      // Status machine may refuse; handover row still exists for confirmation.
    }
  }

  return { handover, created };
}

async function confirm(handoverId, user) {
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

  // Dual confirmation: each party stamps their side; admin stamps both.
  const handover = await repository.markConfirmed(raw.id, {
    byCollector: isCollector || isAdmin,
    byRecycler: isRecycler || isAdmin,
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
