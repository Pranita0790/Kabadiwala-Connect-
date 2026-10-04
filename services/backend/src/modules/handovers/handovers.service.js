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
const notificationService = require("../notifications/notifications.service");
const recyclersRepository = require("../recyclers/recyclers.repository");
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

function actorName(user) {
  return user?.fullName || user?.organisationName || "The recycler";
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
  // Collector app starts PIN handover → lot must land in Verification
  // (Accepted/Handover). Collectors cannot call changeStatus for those
  // transitions, so the handover sync path updates the lot row directly
  // after the handover record exists.
  let current = lot;
  try {
    if (
      user.role === userRole.RECYCLER ||
      user.role === userRole.ADMIN
    ) {
      if (current.status === lotStatus.PENDING) {
        const accepted = await lotsService.changeStatus(
          current.id,
          lotStatus.ACCEPTED,
          user,
          { note: "Auto-accepted for handover sync" }
        );
        current = accepted?.lot || current;
      }
      const fresh = await lotsRepository.findByAnyIdentifier(current.id);
      current = fresh || current;
      if (current.status === lotStatus.ACCEPTED) {
        await lotsService.changeStatus(current.id, lotStatus.HANDOVER, user, {
          note: "Handover created",
        });
      }
      return;
    }

    // Collector PIN sync: put the lot on the recycler Verification queue.
    // Re-open COMPLETED lots too — collectors often re-send the same lot after
    // an earlier demo/auto-confirm, and Verification only lists Handover/Accepted.
    if (
      current.status === lotStatus.PENDING ||
      current.status === lotStatus.ACCEPTED ||
      current.status === lotStatus.COMPLETED ||
      current.status === lotStatus.HANDOVER
    ) {
      const patch = {
        status: lotStatus.HANDOVER,
        recyclerId: current.recyclerId || null,
      };
      if (current.status === lotStatus.COMPLETED) {
        patch.completedAt = null;
      }
      const { lot: updated } = await lotsRepository.update(current.internalId, patch);
      current = updated || current;
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

  // Destination facility from the collector app wins. Dual-use accounts
  // (collector phone that also has a website org) must NOT auto-bind the
  // lot to themselves — otherwise Green Earth never sees the handover.
  let recyclerId = lot.recyclerId;

  if (input.recyclerId || input.recycler_id) {
    // Collector may pass a recycler profile UUID, or a demo/local id / org name.
    const candidate = String(input.recyclerId || input.recycler_id || "").trim();
    if (isUuid(candidate)) {
      recyclerId = candidate;
    } else if (candidate) {
      const byName =
        (await recyclersRepository.findIdByOrganisationName(candidate)) ||
        (await recyclersRepository.findIdByOrganisationName(
          input.recyclerName || input.recycler_name || ""
        ));
      if (byName) {
        recyclerId = byName;
      }
    }
  }

  if (!recyclerId && (input.recyclerName || input.recycler_name)) {
    const byName = await recyclersRepository.findIdByOrganisationName(
      input.recyclerName || input.recycler_name
    );
    if (byName) {
      recyclerId = byName;
    }
  }

  // Website-created handovers with no destination fall back to the actor's org.
  if (!recyclerId && user.role === userRole.RECYCLER && user.recyclerId) {
    recyclerId = user.recyclerId;
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

  // Always refresh lot status (including re-uploads of the same handover).
  await advanceLotTowardHandover(lot, user);

  return { handover, created };
}

async function confirm(handoverId, user, options = {}) {
  let raw = await repository.findRawByPublicId(handoverId);
  if (!raw) {
    const lotForId = await lotsRepository.findByAnyIdentifier(handoverId);
    if (lotForId) {
      raw = await repository.findRawLatestByLotInternalId(lotForId.internalId);
      if (!raw) {
        const created = await create({ lotId: lotForId.id }, user);
        raw = await repository.findRawByPublicId(created.handover.id);
      }
    }
  }
  if (!raw) {
    throw new NotFoundError(`Handover "${handoverId}" not found`);
  }

  const lot = await lotsRepository.findByAnyIdentifier(raw.lot_public_id);
  if (!lot) {
    throw new NotFoundError("Linked lot not found");
  }

  const isCollector = user.role === userRole.COLLECTOR && lot.collectorId === user.id;
  // Accounts with a recycler_profiles row can confirm even if role is still
  // COLLECTOR (dual-use demo phones that also run the website).
  const isRecycler =
    Boolean(user.recyclerId) &&
    (user.role === userRole.RECYCLER || user.role === userRole.COLLECTOR) &&
    (!raw.recycler_id || raw.recycler_id === user.recyclerId);
  const isAdmin = user.role === userRole.ADMIN;

  if (!isCollector && !isRecycler && !isAdmin) {
    throw new AuthorizationError("You cannot confirm this handover");
  }

  // Only recycler/admin may stamp both sides (website pay+verify).
  // Collectors must never auto-complete — that hid lots from Verification.
  const completeBoth =
    Boolean(options.completeBoth || options.demoComplete) &&
    (isRecycler || isAdmin);

  const handover = await repository.markConfirmed(raw.id, {
    byCollector: isCollector || isAdmin || completeBoth,
    byRecycler: isRecycler || isAdmin || completeBoth,
  });

  if (handover?.status === "CONFIRMED") {
    const fromBody = Number(options.finalAmount);
    const amount = Number.isFinite(fromBody) && fromBody > 0
      ? fromBody
      : Number(lot.estimatedValue || handover.agreedAmount || 0);

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

    try {
      await notificationService.create({
        userId: lot.collectorId,
        lotId: lot.internalId,
        type: "HANDOVER_CONFIRMED",
        titleEn: "Payment received",
        bodyEn: `${actorName(user)} paid ₹${amount.toFixed(0)} for your ${handover.materialCategory || lot.categoryName || "lot"} (${handover.weightKg || lot.weightKg || 0} kg).`,
        titleHi: "भुगतान प्राप्त हुआ",
        titleMr: "पेमेंट मिळाला",
        bodyHi: `आपके माल के लिए ₹${amount.toFixed(0)} का भुगतान हो गया है।`,
        bodyMr: `तुमच्या मालासाठी ₹${amount.toFixed(0)} पेमेंट झाले आहे.`,
      });
    } catch {
      // Settlement still stands if the inbox write fails.
    }

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
