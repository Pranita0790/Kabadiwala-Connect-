/*
|--------------------------------------------------------------------------
| RATES SCHEMAS
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const region = z
  .string()
  .trim()
  .regex(/^[A-Z]{2}-[A-Z]{2,3}$/, "Region must look like IN-MH")
  .optional();

const byId = {
  params: z.object({
    id: z
      .string()
      .trim()
      .min(1, "Rate id is required")
      .max(64)
      .regex(/^[a-z0-9-]+$/i, "Rate id may contain letters, digits and dashes"),
  }),
  query: z.object({ region }).strip(),
};

const updateRate = {
  body: z
    .object({
      ratePerKg: z
        .union([
          z.number().nonnegative("ratePerKg cannot be negative").finite(),
          z
            .string()
            .trim()
            .regex(/^\d+(\.\d+)?$/, "ratePerKg must be a number")
            .transform((value) => Number(value)),
        ])
        .refine((value) => value >= 0, "ratePerKg cannot be negative"),
      source: z.string().trim().max(120).optional(),
    })
    .strict(),
};

const listQuery = {
  query: z.object({ region }).strip(),
};

module.exports = { byId, updateRate, listQuery };