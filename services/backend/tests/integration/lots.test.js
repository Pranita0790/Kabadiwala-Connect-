/*
|--------------------------------------------------------------------------
| LOTS INTEGRATION
|--------------------------------------------------------------------------
| Covers the domain rules AGENTS.md section 14 requires:
| - offline sync idempotency on clientReference
| - conflict reporting rather than silent overwrite
| - handover/traceability status transitions
| - value estimation from the rate card, not from the client
|
| These run against a real PostgreSQL because every assertion here is about
| SQL behaviour (constraints, version columns, unique indexes) that a mocked
| repository cannot reproduce.
|--------------------------------------------------------------------------
*/

const {
  describeIntegration,
  resetDb,
  createUser,
  createRecycler,
  collectorUser,
  teardown,
} = require("../helpers/db");

const lotsService = require("../../src/modules/lots/lots.service");
const lotsRepository = require("../../src/modules/lots/lots.repository");
const traceabilityService = require("../../src/modules/traceability/traceability.service");
const traceabilityRepository = require("../../src/modules/traceability/traceability.repository");
const { lotStatus, LOT_STATUS_TRANSITIONS } = require("../../src/config/constants");

// Client references are UUIDs minted on the device (lib/ids.newClientReference).
const { randomUUID } = require("node:crypto");

describeIntegration("lots", () => {
  beforeEach(async () => {
    await resetDb();
  });

  afterAll(teardown);

  let collectorId;
  let otherCollectorId;
  let user;

  beforeEach(async () => {
    collectorId = await createUser({ fullName: "Asha Collector" });
    otherCollectorId = await createUser({ fullName: "Other Collector" });
    user = collectorUser(collectorId, { fullName: "Asha Collector" });
  });

  function lotInput(overrides = {}) {
    return {
      materialId: "pcb",
      weightKg: 4,
      collectionAddress: "Sector 21, Pune",
      ...overrides,
    };
  }

  describe("create", () => {
    it("assigns a human lot number and starts in PENDING", async () => {
      const { lot, created } = await lotsService.create(lotInput(), user);

      expect(created).toBe(true);
      expect(lot.status).toBe(lotStatus.PENDING);
      expect(lot.lotNumber).toMatch(/^KC-\d{4}-\d{4}$/);
    });

    it("derives the value estimate from the rate card", async () => {
      const { lot } = await lotsService.create(
        lotInput({ materialId: "cable", weightKg: 10 }),
        user
      );

      expect(lot.estimatedValue).toBeGreaterThan(0);
      expect(lot.currency).toBe("INR");
    });

    it("rejects a material that is not in the catalogue", async () => {
      await expect(lotsService.create(lotInput({ materialId: "unobtanium" }), user))
        .rejects.toThrow(/Unknown material/i);
    });

    it("records a Collection traceability event on creation", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const events = await traceabilityRepository.listEvents(lot.internalId);

      expect(events).toHaveLength(1);
      expect(events[0].stage).toBe("Collection");
      expect(events[0].actorType).toBe("COLLECTOR");
    });

    it("gives consecutive lots distinct numbers", async () => {
      const first = await lotsService.create(lotInput(), user);
      const second = await lotsService.create(lotInput(), user);

      expect(first.lot.lotNumber).not.toBe(second.lot.lotNumber);
    });
  });

  describe("offline sync idempotency", () => {
    it("returns the existing lot when the same clientReference is replayed", async () => {
      const clientReference = randomUUID();

      const first = await lotsService.create(
        lotInput({ clientReference }),
        user
      );
      const second = await lotsService.create(
        lotInput({ clientReference }),
        user
      );

      expect(first.created).toBe(true);
      expect(second.created).toBe(false);
      expect(second.lot.id).toBe(first.lot.id);
      expect(second.lot.lotNumber).toBe(first.lot.lotNumber);
    });

    it("does not duplicate the Collection event on replay", async () => {
      const clientReference = randomUUID();

      const first = await lotsService.create(lotInput({ clientReference }), user);
      await lotsService.create(lotInput({ clientReference }), user);

      const events = await traceabilityRepository.listEvents(first.lot.internalId);

      expect(events).toHaveLength(1);
    });
  });

  describe("sync batch", () => {
    it("creates new items and reports replays as unchanged", async () => {
      const items = [
        { ...lotInput({ clientReference: randomUUID() }) },
        { ...lotInput({ clientReference: randomUUID() }) },
      ];

      const firstPass = await lotsService.syncBatch(items, user);

      expect(firstPass.created).toBe(2);
      expect(firstPass.failed).toBe(0);

      const secondPass = await lotsService.syncBatch(items, user);

      expect(secondPass.created).toBe(0);
      expect(secondPass.unchanged).toBe(2);
    });

    it("fails one item without aborting the batch", async () => {
      const results = await lotsService.syncBatch(
        [
          { ...lotInput({ clientReference: randomUUID() }) },
          { ...lotInput({ clientReference: randomUUID(), materialId: "unobtanium" }) },
          { ...lotInput({ clientReference: randomUUID() }) },
        ],
        user
      );

      expect(results.processed).toBe(3);
      expect(results.created).toBe(2);
      expect(results.failed).toBe(1);
      expect(results.items[1].outcome).toBe("failed");
    });

    it("requires a clientReference for idempotency", async () => {
      const results = await lotsService.syncBatch([lotInput()], user);

      expect(results.failed).toBe(1);
      expect(results.items[0].error.message).toMatch(/clientReference/i);
    });

    it("reports a conflict when the server copy is newer", async () => {
      const clientReference = randomUUID();
      const { lot } = await lotsService.create(
        lotInput({ clientReference }),
        user
      );

      // Server side moves the lot on; the device still has the older copy.
      const recyclerId = await createRecycler();
      const recyclerUser = {
        id: `recycler-${recyclerId}`,
        publicId: "22222222-2222-4222-8222-222222222222",
        role: "RECYCLER",
        fullName: "Rita Recycle",
        recyclerId,
      };

      await lotsService.changeStatus(lot.id, lotStatus.ACCEPTED, recyclerUser);

      // The device reports an updatedAt older than the server's.
      const staleTimestamp = new Date(Date.now() - 60_000).toISOString();
      const results = await lotsService.syncBatch(
        [{ ...lotInput({ clientReference }), updatedAt: staleTimestamp }],
        user
      );

      expect(results.conflicts).toBe(1);
      expect(results.items[0].outcome).toBe("conflict");
      expect(results.items[0].lot.status).toBe(lotStatus.ACCEPTED);
    });
  });

  describe("status transitions", () => {
    it("refuses to skip a stage", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const recyclerId = await createRecycler();
      const recyclerUser = {
        id: `recycler-${recyclerId}`,
        publicId: "33333333-3333-4333-8333-333333333333",
        role: "RECYCLER",
        fullName: "Rita Recycle",
        recyclerId,
      };

      // PENDING -> COMPLETED is not an edge in the machine.
      expect(LOT_STATUS_TRANSITIONS.PENDING).not.toContain(lotStatus.COMPLETED);

      await expect(
        lotsService.changeStatus(lot.id, lotStatus.COMPLETED, recyclerUser)
      ).rejects.toThrow(/cannot move to COMPLETED/i);
    });

    it("walks the full lifecycle and appends an event per transition", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const recyclerId = await createRecycler();
      const recyclerUser = {
        id: `recycler-${recyclerId}`,
        publicId: "44444444-4444-4444-8444-444444444444",
        role: "RECYCLER",
        fullName: "Rita Recycle",
        recyclerId,
      };

      for (const status of [
        lotStatus.ACCEPTED,
        lotStatus.HANDOVER,
        lotStatus.COMPLETED,
      ]) {
        const result = await lotsService.changeStatus(
          lot.id,
          status,
          recyclerUser
        );

        expect(result.changed).toBe(true);
        expect(result.lot.status).toBe(status);
      }

      const events = await traceabilityRepository.listEvents(lot.internalId);

      // Collection + one event per transition.
      expect(events).toHaveLength(4);
      expect(events.map((event) => event.sequenceNo)).toEqual([1, 2, 3, 4]);
    });

    it("is idempotent when the same transition is retried", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const recyclerId = await createRecycler();
      const recyclerUser = {
        id: `recycler-${recyclerId}`,
        publicId: "55555555-5555-4555-8555-555555555555",
        role: "RECYCLER",
        fullName: "Rita Recycle",
        recyclerId,
      };

      await lotsService.changeStatus(lot.id, lotStatus.ACCEPTED, recyclerUser);
      const retry = await lotsService.changeStatus(
        lot.id,
        lotStatus.ACCEPTED,
        recyclerUser
      );

      expect(retry.changed).toBe(false);

      const events = await traceabilityRepository.listEvents(lot.internalId);

      // Collection + one Accepted; the retry must not add a second.
      expect(events).toHaveLength(2);
    });

    it("stops a collector from driving the workflow", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      await expect(
        lotsService.changeStatus(lot.id, lotStatus.ACCEPTED, user)
      ).rejects.toThrow(/only a recycler or an administrator/i);
    });
  });

  describe("ownership", () => {
    it("hides another collector's lot as not found", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const stranger = collectorUser(otherCollectorId, {
        fullName: "Other Collector",
      });

      await expect(lotsService.getByIdentifier(lot.id, stranger)).rejects.toThrow(
        /Lot not found/i
      );
    });

    it("stops a collector editing another collector's lot", async () => {
      const { lot } = await lotsService.create(lotInput(), user);
      const stranger = collectorUser(otherCollectorId);

      await expect(
        lotsService.update(lot.id, { notes: "tampered" }, stranger)
      ).rejects.toThrow(/only change your own lots/i);
    });

    it("refuses a status change through the content endpoint", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      await expect(
        lotsService.update(lot.id, { status: lotStatus.COMPLETED }, user)
      ).rejects.toThrow(/PATCH \/api\/lots\/:id\/status/);
    });
  });

  describe("lookup by identifier", () => {
    it("finds a lot by its public uuid", async () => {
      const { lot } = await lotsService.create(lotInput(), user);
      const found = await lotsRepository.findByAnyIdentifier(lot.id);

      expect(found.id).toBe(lot.id);
    });

    it("finds a lot by its human number without a uuid cast error", async () => {
      const { lot } = await lotsService.create(lotInput(), user);
      const found = await lotsRepository.findByAnyIdentifier(lot.lotNumber);

      expect(found.id).toBe(lot.id);
    });

    it("accepts a lower-case human number", async () => {
      const { lot } = await lotsService.create(lotInput(), user);
      const found = await lotsRepository.findByAnyIdentifier(
        lot.lotNumber.toLowerCase()
      );

      expect(found.id).toBe(lot.id);
    });
  });

  describe("withdrawal", () => {
    it("hides a withdrawn lot from lookups but keeps the row", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      await lotsService.remove(lot.id, user);

      // Gone from every collector-facing lookup...
      expect(await lotsRepository.findByAnyIdentifier(lot.id)).toBeNull();
      await expect(
        lotsService.getByIdentifier(lot.id, user)
      ).rejects.toThrow(/not found/i);

      // ...but the row survives, so the audit trail keeps its foreign keys.
      // AGENTS.md section 8: never delete production data.
      const { queryOne } = require("../../src/db/query");
      const row = await queryOne(
        "SELECT deleted_at, lot_number FROM lots WHERE id = $1",
        [lot.internalId]
      );

      expect(row).not.toBeNull();
      expect(row.deleted_at).not.toBeNull();
      expect(row.lot_number).toBe(lot.lotNumber);
    });
  });

  describe("AI analysis attachment", () => {
    it("stores the inference and its wording", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const result = await lotsService.attachAnalysis(
        lot.id,
        {
          material: "pcb",
          materialId: "pcb",
          confidence: 0.91,
          isLowConfidence: false,
          criticalMineral: true,
          criticalMineralReason:
            "Potential copper and precious-metal-bearing traces. Rule-based inference, not laboratory analysis.",
          modelVersion: "sih-5class-v1",
          ruleVersion: "rules-1",
          weightEstimate: { value: 3.2 },
        },
        user
      );

      expect(result.lot.aiConfidence).toBeCloseTo(0.91);
      expect(result.lot.criticalMineral).toBe(true);

      const analyses = await lotsService.getAnalyses(lot.id, user);

      expect(analyses).toHaveLength(1);
      expect(analyses[0].materialPredicted).toBe("pcb");
    });

    it("warns when confidence is below the threshold", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const result = await lotsService.attachAnalysis(
        lot.id,
        {
          material: "cable",
          materialId: "cable",
          confidence: 0.2,
          isLowConfidence: true,
          criticalMineral: false,
          criticalMineralReason: null,
          modelVersion: "sih-5class-v1",
          ruleVersion: "rules-1",
        },
        user
      );

      expect(result.warnings.join(" ")).toMatch(/below the 0.6 threshold/i);
    });

    it("never overwrites a measured weight with the model's estimate", async () => {
      const { lot } = await lotsService.create(lotInput({ weightKg: 7.5 }), user);

      const result = await lotsService.attachAnalysis(
        lot.id,
        {
          material: "pcb",
          materialId: "pcb",
          confidence: 0.95,
          isLowConfidence: false,
          criticalMineral: true,
          criticalMineralReason: "Potential traces.",
          modelVersion: "sih-5class-v1",
          ruleVersion: "rules-1",
          weightEstimate: { value: 1.1 },
        },
        user
      );

      expect(result.lot.weightKg).toBeCloseTo(7.5);
    });
  });

  describe("traceability record shape", () => {
    it("exposes the fields the Recycler Dashboard requires", async () => {
      const { lot } = await lotsService.create(
        lotInput({ materialId: "pcb", weightKg: 4 }),
        user
      );

      const record = await traceabilityService.getByIdentifier(lot.id);

      // normalizeLot() in the dashboard drops a record missing any of these.
      expect(typeof record.id).toBe("string");
      expect(typeof record.material).toBe("string");
      expect(typeof record.collector).toBe("string");
      expect(typeof record.weight).toBe("number");

      // A Date in the DTO, which Express serialises to the ISO string the
      // dashboard's `new Date(record.createdAt)` expects.
      expect(record.createdAt).toBeInstanceOf(Date);
      expect(JSON.parse(JSON.stringify(record)).createdAt).toEqual(
        expect.any(String)
      );

      expect(record.collector).toBe("Asha Collector");

      // Title Cased label, because LotStatus is a union of those literals.
      expect(record.status).toBe("Pending");
    });

    it("derives journey position from the lot's current status", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const recyclerId = await createRecycler();
      const recyclerUser = {
        id: `recycler-${recyclerId}`,
        publicId: "66666666-6666-4666-8666-666666666666",
        role: "RECYCLER",
        fullName: "Rita Recycle",
        recyclerId,
      };

      await lotsService.changeStatus(lot.id, lotStatus.HANDOVER, {
        ...recyclerUser,
      }).catch(async () => {
        // Must pass through ACCEPTED first.
        await lotsService.changeStatus(lot.id, lotStatus.ACCEPTED, recyclerUser);
        return lotsService.changeStatus(lot.id, lotStatus.HANDOVER, recyclerUser);
      });

      const record = await traceabilityService.getByIdentifier(lot.id);

      // Only statuses the dashboard's JourneyStatus type accepts.
      for (const event of record.events) {
        expect(["completed", "current", "pending"]).toContain(event.status);
      }

      expect(record.status).toBe("Handover");
      expect(record.currentStage).toBe("Processing");
    });

    it("filters by the Title Cased status the dashboard sends", async () => {
      const { lot } = await lotsService.create(lotInput(), user);

      const matched = await traceabilityService.list({ status: "Pending" });
      const unmatched = await traceabilityService.list({ status: "Completed" });

      expect(matched.records.map((record) => record.lotId)).toContain(lot.id);
      expect(unmatched.records.map((record) => record.lotId)).not.toContain(lot.id);
    });

    it("returns nothing for an unknown status filter instead of every lot", async () => {
      await lotsService.create(lotInput(), user);

      const result = await traceabilityService.list({ status: "Nonsense" });

      expect(result.records).toHaveLength(0);
    });
  });
});