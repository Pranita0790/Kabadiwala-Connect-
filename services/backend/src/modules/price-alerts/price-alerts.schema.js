/*
|--------------------------------------------------------------------------
| PRICE ALERTS SCHEMAS
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const create = {
  body: z
    .object({
      materialId: z
        .string()
        .trim()
        .min(1)
        .max(64)
        .regex(/^[a-z0-9_-]+$/i, "materialId is not a valid material id"),
      targetRatePerKg: z
        .union([
          z.number().nonnegative().finite(),
          z
            .string()
            .trim()
            .regex(/^\d+(\.\d+)?$/, "targetRatePerKg must be a number")
            .transform((value) => Number(value)),
        ])
        .refine((value) => value >= 0, "targetRatePerKg cannot be negative"),
      direction: z.enum(["ABOVE", "BELOW"]).default("ABOVE"),
      region: z
        .string()
        .trim()
        .regex(/^[A-Z]{2}-[A-Z]{2,3}$/)
        .optional()
        .default("IN-MH"),
    })
    .strict(),
};

const list = {
  query: z
    .object({
      page: z.coerce.number().int().positive().optional(),
      pageSize: z.coerce.number().int().positive().max(100).optional(),
      activeOnly: z
        .enum(["true", "false"])
        .optional()
        .transform((value) => value === "true"),
    })
    .strip(),
};

const byId = {
  params: z.object({
    id: z.string().uuid("Price alert id must be a UUID"),
  }),
};

module.exports = { create, list, byId };