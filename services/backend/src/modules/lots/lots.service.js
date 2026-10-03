/*
|--------------------------------------------------------------------------
| LOTS SERVICE
|--------------------------------------------------------------------------
| Lot business rules.
|
| Three rules are enforced here rather than in a client, because both the
| collector app and the Recycler Dashboard drive the same transitions and
| neither can be trusted to agree on them:
|
|   1. Status transitions follow LOT_STATUS_TRANSITIONS. A lot cannot jump
|      from PENDING straight to COMPLETED, because that would skip handover
|      and settlement in the traceability record.
|   2. Every status change appends a traceability event. The timeline is a
|      consequence of the transition, never a separately maintained field.
|   3. Offline sync is idempotent on clientReference, and a stale write is
|      reported as a conflict rather than silently overwriting.
|
| Ownership is checked here too: an authenticated collector may only read or
| change their own lots, unless they hold the recycler or admin role.
|--------------------------------------------------------------------------
*/

const repository = require("./lots.repository");
const traceabilityService = require("../traceability/traceability.service");
const ratesService = require("../rates/rates.service");
const materialsRepository = require("../materials/materials.repository");
const notificationService = require("../notifications/notifications.service");
const aiAnalysesRepository = require("./ai-analyses.repository");
const logger = require("../../lib/logger");
const {
  canTransitionLotStatus,
  lotStatus,
  userRole,
  LOT_STATUS_TRANSITIONS,
  CRITICAL_MINERAL_POTENTIAL_MESSAGE,
  AI_DISCLAIMER,
} = require("../../config/constants");
const {
  NotFoundError,
  AuthorizationError,
  ConflictError,
  ValidationError,
} = require("../../lib/errors");

/*
|--------------------------------------------------------------------------
| ACCESS CONTROL
|--------------------------------------------------------------------------
*/

/**
 * Who may see a lot.
 *
 *   - the collector who recorded it
 *   - the recycler it is assigned to
 *   - an administrator
 *   - ANY authorised recycler while the lot is still unclaimed
 *
 * That last case is required, not a convenience. A lot is created with
 * recycler_id NULL, so if visibility were limited to the assigned recycler,
 * no recycler could ever see an available lot and the accept step would be
 * unreachable — the platform would have no way to match supply to demand.
 * Once a recycler claims a lot the field is set and other recyclers lose
 * access, which is what stops two recyclers working the same lot.
 */
function assertCanView(lot, user) {
  if (user.role === userRole.ADMIN) {
    return;
  }

  const isCollector = lot.collectorId === user.id;
  const isAssignedRecycler = Boolean(
    user.recyclerId && lot.recyclerId === user.recyclerId
  );

  // An unclaimed lot is open to any recycler that actually has a profile.
  const isUnclaimed = lot.recyclerId === null || lot.recyclerId === undefined;
  const isRecyclerWithProfile =
    user.role === userRole.RECYCLER && Boolean(user.recyclerId);

  if (isCollector || isAssignedRecycler || (isUnclaimed && isRecyclerWithProfile)) {
    return;
  }

  // 404 rather than 403: a collector should not be able to probe whether
  // a lot exists by watching for 403.
  throw new NotFoundError("Lot not found", { lotId: lot.id });
}

/**
 * Only the collector who owns the lot, or an administrator, may edit its
 * content. Recycler-facing changes go through the status endpoint.
 */
function assertCanEdit(lot, user) {
  if (user.role === userRole.ADMIN) {
    return;
  }

  if (lot.collectorId !== user.id) {
    throw new AuthorizationError("You can only change your own lots");
  }
}

/*
|--------------------------------------------------------------------------
| CREATE
|--------------------------------------------------------------------------
*/

/**
 * Create a lot.
 *
 * @param {object} input
 * @param {object} user  Authenticated creator
 * @returns {{lot, created, warnings}}
 */
async function create(input, user) {
  const collectorId =
    user.role === userRole.ADMIN && input.collectorId
      ? input.collectorId
      : user.id;

  if (input.materialId) {
    const material = await materialsRepository.findById(input.materialId);

    if (!material) {
      throw new ValidationError(
        `Unknown material "${input.materialId}". Send GET /api/materials for valid ids.`,
        { materialId: input.materialId }
      );
    }
  }

  // Idempotent re-submission from an offline device.
  if (input.clientReference) {
    const existing = await repository.findByClientReference(input.clientReference);

    if (existing) {
      return { lot: existing, created: false, warnings: [] };
    }
  }

  // An estimate is derived, never taken from the client: a submitted
  // estimatedValue is not trusted over the rate card.
  const estimate = await deriveEstimate(input);

  const { lot, created } = await repository.create({
    clientReference: input.clientReference,
    collectorId,
    materialId: input.materialId ?? null,
    categoryName: input.categoryName ?? null,
    condition: input.condition ?? null,
    weightKg: input.weightKg ?? null,
    status: lotStatus.PENDING,
    syncStatus: input.syncStatus ?? "SYNCED",
    aiConfidence: input.aiConfidence ?? null,
    criticalMineral: input.criticalMineral ?? null,
    criticalMineralReason: input.criticalMineralReason ?? null,
    modelVersion: input.modelVersion ?? null,
    ruleVersion: input.ruleVersion ?? null,
    estimatedValue: estimate.estimatedValue,
    estimatedMinValue: estimate.estimatedMinValue,
    estimatedMaxValue: estimate.estimatedMaxValue,
    estimatedCurrency: "INR",
    estimatedAt: estimate.estimatedValue === null ? null : new Date(),
    imagePath: input.imagePath ?? null,
    notes: input.notes ?? null,
    collectionAddress: input.collectionAddress ?? null,
    collectionLatitude: input.collectionLatitude ?? null,
    collectionLongitude: input.collectionLongitude ?? null,
  });

  if (created) {
    // A new lot always starts its journey at Collection.
    await traceabilityService.recordEvent(lot, {
      stage: "Collection",
      title: "Lot collected",
      description:
        "Material was collected and registered by the collector.",
      actor: user.fullName,
      actorType: userRole.COLLECTOR,
      location: input.collectionAddress ?? null,
    });

    logger.info("Lot created", {
      lotId: lot.id,
      lotNumber: lot.lotNumber,
      collectorId: user.publicId,
      criticalMineral: lot.criticalMineral,
    });
  }

  return { lot, created, warnings: estimate.warnings };
}

/**
 * Derive the indicative value from the rate card.
 *
 * If the AI service supplied its own value estimate it is surfaced alongside
 * the rate-card figure so the client can show the range rather than a single
 * authoritative-looking number.
 */
async function deriveEstimate(input) {
  const warnings = [];

  if (!input.materialId || !input.weightKg) {
    warnings.push(
      "Add a material and weight to receive an indicative value estimate."
    );

    return {
      estimatedValue: null,
      estimatedMinValue: null,
      estimatedMaxValue: null,
      warnings,
    };
  }

  try {
    const estimate = await ratesService.calculateIndicativeValue({
      materialId: input.materialId,
      weightKg: input.weightKg,
    });

    if (estimate.estimatedValue === null) {
      warnings.push(
        `No current rate for ${input.materialId}; this lot has no value estimate yet.`
      );
    }

    return { ...estimate, warnings };
  } catch (error) {
    // A rate lookup failure must not prevent a lot from being recorded.
    logger.warn("Rate lookup failed while estimating lot value", {
      lotMaterial: input.materialId,
      message: error.message,
    });

    warnings.push("Value estimate unavailable right now.");

    return {
      estimatedValue: null,
      estimatedMinValue: null,
      estimatedMaxValue: null,
      warnings,
    };
  }
}

/*
|--------------------------------------------------------------------------
| READ
|--------------------------------------------------------------------------
*/

async function getByIdentifier(identifier, user) {
  const lot = await repository.findByAnyIdentifier(identifier);

  if (!lot) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  assertCanView(lot, user);

  return lot;
}

async function list(filters, user) {
  // A collector's list is scoped to their own lots by default. An explicit
  // request for someone else's lots is only honoured for recycler/admin.
  const scoped = { ...filters };

  if (user.role === userRole.COLLECTOR) {
    scoped.collectorId = user.id;
  } else if (user.role === userRole.RECYCLER) {
    // Incoming feed: lots already claimed by this recycler, plus unclaimed
    // PENDING lots any authorized recycler can accept.
    scoped.recyclerId = scoped.recyclerId || user.recyclerId;
    scoped.includeUnclaimedForRecycler = true;
  }

  return repository.list(scoped, {
    limit: filters.limit,
    offset: filters.offset,
  });
}

/*
|--------------------------------------------------------------------------
| UPDATE CONTENT
|--------------------------------------------------------------------------
*/

/**
 * Update a lot's editable fields.
 *
 * @param {object} params
 * @param {string|number} params.expectedVersion  Optimistic concurrency token
 */
async function update(identifier, patch, user, { expectedVersion = null } = {}) {
  const existing = await repository.findByAnyIdentifier(identifier);

  if (!existing) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  assertCanEdit(existing, user);

  // A collector may not set a status through the content endpoint; status
  // changes are the domain transition endpoint.
  if (patch.status !== undefined) {
    throw new ValidationError(
      "Use PATCH /api/lots/:id/status to change the status of a lot.",
      { field: "status" }
    );
  }

  const updatePatch = { ...patch };

  // Re-derive the estimate whenever the inputs to it change.
  const weightChanged = updatePatch.weightKg !== undefined;
  const materialChanged = updatePatch.materialId !== undefined;

  if (weightChanged || materialChanged) {
    const estimate = await deriveEstimate({
      materialId: updatePatch.materialId ?? existing.materialId,
      weightKg: updatePatch.weightKg ?? existing.weightKg,
    });

    if (estimate.estimatedValue !== null) {
      Object.assign(updatePatch, {
        estimatedValue: estimate.estimatedValue,
        estimatedMinValue: estimate.estimatedMinValue,
        estimatedMaxValue: estimate.estimatedMaxValue,
        estimatedAt: new Date(),
      });
    }
  }

  const result = await repository.update(existing.internalId, updatePatch, {
    expectedVersion,
  });

  if (result.conflict) {
    throw new ConflictError(
      "This lot was changed on the server while your device was offline. " +
        "Fetch the latest version and merge your changes.",
      "SYNC_CONFLICT",
      {
        lotId: existing.id,
        serverVersion: result.lot?.version,
        clientVersion: expectedVersion,
        serverUpdatedAt: result.lot?.updatedAt,
      }
    );
  }

  logger.info("Lot updated", {
    lotId: result.lot.id,
    lotNumber: result.lot.lotNumber,
    actorId: user.publicId,
    fields: Object.keys(updatePatch),
  });

  return result.lot;
}

/*
|--------------------------------------------------------------------------
| STATUS TRANSITION
|--------------------------------------------------------------------------
*/

/**
 * Move a lot to a new status, appending the matching traceability event.
 */
async function changeStatus(identifier, nextStatus, user, { note } = {}) {
  const existing = await repository.findByAnyIdentifier(identifier);

  if (!existing) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  assertCanView(existing, user);

  // A collector can withdraw their own lot; a recycler or admin drives the
  // rest of the workflow.
  const collectorActions = [lotStatus.REJECTED];
  const isOwner = existing.collectorId === user.id;

  if (isOwner && collectorActions.includes(nextStatus)) {
    // allowed
  } else if (user.role !== userRole.RECYCLER && user.role !== userRole.ADMIN) {
    throw new AuthorizationError(
      "Only a recycler or an administrator can move a lot through the workflow."
    );
  }

  if (existing.status === nextStatus) {
    // Idempotent: a retried request must not duplicate a timeline event.
    return { lot: existing, changed: false };
  }

  if (!canTransitionLotStatus(existing.status, nextStatus)) {
    throw new ConflictError(
      `A lot in status ${existing.status} cannot move to ${nextStatus}.`,
      "INVALID_STATUS_TRANSITION",
      {
        currentStatus: existing.status,
        requestedStatus: nextStatus,
        allowedNextStatuses: LOT_STATUS_TRANSITIONS[existing.status] ?? [],
      }
    );
  }

  /*
   | Claiming.
   |
   | Accepting an unclaimed lot assigns it to the accepting recycler. Without
   | this the lot would stay unowned forever: `recycler_id` is only ever set
   | here, and an unassigned lot cannot be filtered by recycler later.
   |
   | Only done on ACCEPTED, and only when the slot is still empty, so a retry
   | cannot steal a lot that another recycler has since claimed. The
   | repository guards this with a conditional UPDATE, so two recyclers
   | accepting the same lot simultaneously cannot both win.
   */
  let claim = { claimed: false, lot: existing };

  if (nextStatus === lotStatus.ACCEPTED && !existing.recyclerId) {
    if (user.role !== userRole.RECYCLER || !user.recyclerId) {
      throw new AuthorizationError(
        "Only a recycler with a registered profile can accept a lot."
      );
    }

    const { lot: claimed, conflict } = await repository.claimForRecycler(
      existing.internalId,
      user.recyclerId,
      lotStatus.ACCEPTED
    );

    if (conflict) {
      throw new ConflictError(
        "This lot was accepted by another recycler a moment ago.",
        "LOT_ALREADY_CLAIMED",
        { lotId: existing.id }
      );
    }

    claim = { claimed: true, lot: claimed };
  }

  const lot =
    claim.claimed
      ? claim.lot
      : await repository.setStatus(existing.internalId, nextStatus);

  await traceabilityService.recordEvent(lot, {
    stage: traceabilityService.stageForStatus(nextStatus),
    title: traceabilityService.titleForStatus(nextStatus),
    description: note || null,
    actor: user.fullName,
    actorType: user.role,
  });

  await notifyStatusChange(lot, nextStatus, user);

  logger.info("Lot status changed", {
    lotId: lot.id,
    lotNumber: lot.lotNumber,
    from: existing.status,
    to: nextStatus,
    actorId: user.publicId,
  });

  return { lot, changed: true };
}

/**
 * Tell the collector when a recycler acts on their lot. A recycler acting on
 * their own lot is not notified.
 */
async function notifyStatusChange(lot, nextStatus, actor) {
  if (lot.collectorId === actor.id) {
    return;
  }

  const messages = {
    [lotStatus.ACCEPTED]: {
      titleEn: `Lot ${lot.lotNumber} accepted`,
      bodyEn: `${actor.fullName || "The recycler"} accepted your lot. Next step: handover.`,
    },
    [lotStatus.REJECTED]: {
      titleEn: `Lot ${lot.lotNumber} rejected`,
      bodyEn: `${actor.fullName || "The recycler"} rejected your lot.`,
    },
    [lotStatus.HANDOVER]: {
      titleEn: `Lot ${lot.lotNumber} in handover`,
      bodyEn: "Your lot is being handed over to the recycling facility.",
    },
    [lotStatus.COMPLETED]: {
      titleEn: `Lot ${lot.lotNumber} completed`,
      bodyEn: "Processing and settlement are complete. Your earnings have been recorded.",
    },
  };

  const message = messages[nextStatus];

  if (!message) {
    return;
  }

  await notificationService.create({
    userId: lot.collectorId,
    lotId: lot.internalId,
    type: "LOT_STATUS",
    titleEn: message.titleEn,
    bodyEn: message.bodyEn,
  });
}

/*
|--------------------------------------------------------------------------
| AI ANALYSIS ATTACHMENT
|--------------------------------------------------------------------------
*/

/**
 * Attach an AI inference to a lot and persist the analysis record so the
 * classification can be explained later.
 */
async function attachAnalysis(identifier, analysis, user) {
  const lot = await repository.findByAnyIdentifier(identifier);

  if (!lot) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  assertCanEdit(lot, user);

  const warnings = [];

  if (analysis.isLowConfidence) {
    warnings.push(
      `Model confidence ${analysis.confidence} is below the ${0.6} threshold. ` +
        "Treat this classification as a suggestion and confirm it with the recycler."
    );
  }

  await aiAnalysesRepository.create({
    lotId: lot.internalId,
    collectorId: user.id,
    imageFilename: analysis.imageFilename ?? null,
    imageSizeBytes: analysis.imageSizeBytes ?? null,
    materialPredicted: analysis.material,
    confidence: analysis.confidence,
    isLowConfidence: analysis.isLowConfidence,
    criticalMineral: analysis.criticalMineral,
    criticalMineralReason: analysis.criticalMineralReason,
    weightEstimateValue: analysis.weightEstimate?.value ?? null,
    valueEstimateMin: analysis.valueEstimate?.min ?? null,
    valueEstimateMax: analysis.valueEstimate?.max ?? null,
    modelVersion: analysis.modelVersion,
    ruleVersion: analysis.ruleVersion,
    latencyMs: analysis.latencyMs ?? null,
  });

  const patch = {
    // Only promote the AI material into the lot when the catalogue knows it.
    materialId:
      analysis.materialId ?? lot.materialId,
    categoryName: analysis.material ?? lot.categoryName,
    aiConfidence: analysis.confidence,
    criticalMineral: analysis.criticalMineral,
    criticalMineralReason: analysis.criticalMineralReason,
    modelVersion: analysis.modelVersion,
    ruleVersion: analysis.ruleVersion,
  };

  // Weight the model suggests, used only when the collector has not entered
  // one — never overriding a human measurement.
  if (
    analysis.weightEstimate?.value != null &&
    (lot.weightKg === null || lot.weightKg === undefined)
  ) {
    patch.weightKg = analysis.weightEstimate.value;

    warnings.push(
      "Weight was estimated from the image. Adjust it if you weighed the material."
    );
  }

  const { lot: updated } = await repository.update(lot.internalId, patch);

  if (updated.criticalMineral) {
    await traceabilityService.recordEvent(updated, {
      stage: "Verification",
      title: "AI material analysis",
      description:
        `Classified as ${analysis.material}` +
        `${analysis.isLowConfidence ? " (low confidence)" : ""}. ` +
        CRITICAL_MINERAL_POTENTIAL_MESSAGE,
      actor: "Kabadiwala AI Engine",
      actorType: "AI",
    });
  }

  return { lot: updated, warnings };
}

/*
|--------------------------------------------------------------------------
| SYNC
|--------------------------------------------------------------------------
*/

/**
 * Synchronise a batch of lots created while offline.
 *
 * Per item outcome:
 *   - created    the lot was new
 *   - unchanged  an identical lot already existed (clientReference replay)
 *   - conflict   the server copy is newer; the client must reconcile
 *
 * A failure on one item does not abort the batch, because a collector with
 * intermittent connectivity must be able to drain the queue item by item.
 */
async function syncBatch(items, user, { conflictStrategy } = {}) {
  const results = {
    processed: 0,
    created: 0,
    unchanged: 0,
    conflicts: 0,
    failed: 0,
    items: [],
  };

  for (const item of items) {
    results.processed += 1;

    try {
      if (!item.clientReference) {
        throw new ValidationError(
          "clientReference is required for offline sync; it is the idempotency key."
        );
      }

      const existing = await repository.findByClientReference(item.clientReference);

      if (existing) {
        // Same lot already known. Decide whether the client is behind.
        const clientUpdatedAt = item.updatedAt
          ? new Date(item.updatedAt)
          : null;

        const serverIsNewer =
          clientUpdatedAt && new Date(existing.updatedAt) > clientUpdatedAt;

        if (serverIsNewer && conflictStrategy !== "CLIENT_WINS") {
          results.conflicts += 1;
          results.items.push({
            clientReference: item.clientReference,
            outcome: "conflict",
            lot: existing,
            message:
              "The server copy is newer. Merge your changes and resubmit, " +
                "or resync with conflictStrategy=CLIENT_WINS.",
          });

          continue;
        }

        results.unchanged += 1;
        results.items.push({
          clientReference: item.clientReference,
          outcome: "unchanged",
          lot: existing,
        });

        continue;
      }

      const created = await create(item, user);

      results.created += 1;
      results.items.push({
        clientReference: item.clientReference,
        outcome: created.created ? "created" : "unchanged",
        lot: created.lot,
        warnings: created.warnings,
      });
    } catch (error) {
      results.failed += 1;
      results.items.push({
        clientReference: item.clientReference ?? null,
        outcome: "failed",
        error: {
          code: error.code || "SYNC_ITEM_FAILED",
          message: error.message,
        },
      });

      logger.warn("Sync item failed", {
        requestId: undefined,
        clientReference: item.clientReference,
        code: error.code,
        message: error.message,
      });
    }
  }

  logger.info("Sync batch processed", {
    actorId: user.publicId,
    processed: results.processed,
    created: results.created,
    unchanged: results.unchanged,
    conflicts: results.conflicts,
    failed: results.failed,
  });

  return results;
}

async function getAnalyses(identifier, user) {
  const lot = await repository.findByAnyIdentifier(identifier);

  if (!lot) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  assertCanView(lot, user);

  return aiAnalysesRepository.listForLot(lot.internalId);
}

/*
|--------------------------------------------------------------------------
| SOFT DELETE
|--------------------------------------------------------------------------
*/

async function remove(identifier, user) {
  const existing = await repository.findByAnyIdentifier(identifier);

  if (!existing) {
    throw new NotFoundError(`Lot "${identifier}" not found`, { lotId: identifier });
  }

  if (user.role !== userRole.ADMIN && existing.collectorId !== user.id) {
    throw new AuthorizationError("You can only withdraw your own lots");
  }

  // The row stays for the audit trail; only the collector-facing view is
  // withdrawn (AGENTS.md section 8).
  await repository.softDelete(existing.internalId);

  logger.info("Lot withdrawn", {
    lotId: existing.id,
    lotNumber: existing.lotNumber,
    actorId: user.publicId,
  });

  return { id: existing.id, lotNumber: existing.lotNumber };
}

module.exports = {
  create,
  getByIdentifier,
  list,
  update,
  changeStatus,
  attachAnalysis,
  syncBatch,
  getAnalyses,
  remove,
  deriveEstimate,
  assertCanView,
  assertCanEdit,
  AI_DISCLAIMER,
};