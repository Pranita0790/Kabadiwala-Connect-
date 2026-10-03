/*
|--------------------------------------------------------------------------
| LOTS SCHEMAS
|--------------------------------------------------------------------------
| Request validation for /api/lots. Field names follow the lot DTO the
| collector app and the Recycler Dashboard already use.
|--------------------------------------------------------------------------
*/

const { z } = require("zod");
const { SYNC_BATCH_MAX_ITEMS } = require("../../config/constants");

const condition = z.enum(["Scrap", "Good", "Partial"]);
const syncStatus = z.enum(["PENDING_SYNC", "SYNCING", "SYNCED", "FAILED"]);

const identifier = z.string().trim().min(1).max(64);

const editableFields = {
  materialId: z.string().trim().min(1).max(64).optional(),
  categoryName: z.string().trim().max(120).optional(),
  condition: condition.optional(),
  weightKg: z.number().positive("weightKg must be greater than 0").finite().optional(),
  syncStatus: syncStatus.optional(),
  aiConfidence: z.number().min(0).max(1).optional(),
  criticalMineral: z.boolean().optional(),
  criticalMineralReason: z.string().trim().max(500).optional(),
  modelVersion: z.string().trim().max(64).optional(),
  ruleVersion: z.string().trim().max(64).optional(),
  imagePath: z.string().trim().max(500).optional(),
  notes: z.string().trim().max(2000).optional(),
  collectionAddress: z.string().trim().max(500).optional(),
  collectionLatitude: z.number().min(-90).max(90).optional(),
  collectionLongitude: z.number().min(-180).max(180).optional(),
};

const byId = {
  params: z.object({ id: identifier }),
};

const create = {
  body: z
    .object({
      clientReference: z.string().uuid().optional(),
      // Admin-only: file a lot on behalf of a collector.
      collectorId: z.string().uuid().optional(),
      ...editableFields,
    })
    .strip(),
};

const update = {
  params: z.object({ id: identifier }),
  body: z
    .object({
      ...editableFields,
      // Optimistic concurrency token for the offline sync path.
      version: z.coerce.number().int().positive().optional(),
    })
    .strip(),
};

const changeStatus = {
  params: z.object({ id: identifier }),
  body: z
    .object({
      status: z.string().trim().min(1).max(32),
      note: z.string().trim().max(500).optional(),
      version: z.coerce.number().int().positive().optional(),
    })
    .strip(),
};

const list = {
  query: z
    .object({
      status: z.string().trim().max(32).optional(),
      materialId: z.string().trim().max(64).optional(),
      criticalOnly: z.enum(["true", "false"]).optional(),
      search: z.string().trim().max(200).optional(),
      since: z.string().datetime().optional(),
      page: z.coerce.number().int().positive().optional(),
      pageSize: z.coerce.number().int().positive().optional(),
      limit: z.coerce.number().int().positive().optional(),
    })
    .strip(),
};

const syncItem = z
  .object({
    clientReference: z.string().uuid(),
    materialId: z.string().trim().min(1).max(64).optional(),
    categoryName: z.string().trim().max(120).optional(),
    condition: condition.optional(),
    weightKg: z.number().positive().finite().optional(),
    syncStatus: syncStatus.optional(),
    ...editableFields,
    updatedAt: z.string().datetime().optional(),
  })
  .strip();

const sync = {
  body: z
    .object({
      items: z.array(syncItem).min(1).max(SYNC_BATCH_MAX_ITEMS),
      conflictStrategy: z
        .enum(["LAST_WRITE_WINS", "BACKEND_WINS", "CLIENT_WINS"])
        .optional(),
    })
    .strip(),
};

const attachAnalysis = {
  params: z.object({ id: identifier }),
  body: z
    .object({
      material: z.string().trim().min(1).max(64),
      materialId: z.string().trim().min(1).max(64).optional(),
      confidence: z.number().min(0).max(1).optional(),
      isLowConfidence: z.boolean().optional(),
      criticalMineral: z.boolean().optional(),
      criticalMineralReason: z.string().trim().max(500).nullable().optional(),
      weightEstimate: z.object({ value: z.number().nonnegative().nullable().optional() }).optional(),
      valueEstimate: z
        .object({
          min: z.number().nullable().optional(),
          max: z.number().nullable().optional(),
        })
        .optional(),
      modelVersion: z.string().trim().max(64).optional(),
      ruleVersion: z.string().trim().max(64).optional(),
      imageFilename: z.string().trim().max(300).optional(),
      imageSizeBytes: z.number().int().nonnegative().optional(),
      latencyMs: z.number().int().nonnegative().optional(),
    })
    .strip(),
};

module.exports = { byId, create, update, changeStatus, list, sync, attachAnalysis };
