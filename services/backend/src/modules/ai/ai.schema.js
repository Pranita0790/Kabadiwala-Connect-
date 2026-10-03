/*
|--------------------------------------------------------------------------
| AI SCHEMAS  →  POST /api/ai/analyze
|--------------------------------------------------------------------------
| The analyze endpoint is multipart/form-data, so its only fields are an
| optional weight (which improves the value estimate) and an optional lot to
| attach the inference to. Both the snake_case spelling the deployed clients
| use and a camelCase alias are accepted; unknown fields are stripped.
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const positiveNumber = z
  .union([
    z.number().positive("must be greater than 0").finite(),
    z
      .string()
      .trim()
      .regex(/^\d+(\.\d+)?$/, "must be a number")
      .transform((value) => Number(value))
      .refine((value) => value > 0, "must be greater than 0"),
  ])
  .optional();

const optionalId = z.string().trim().min(1).max(64).optional();

const analyze = {
  body: z
    .object({
      weight_kg: positiveNumber,
      weightKg: positiveNumber,
      lot_id: optionalId,
      lotId: optionalId,
    })
    .strip(),
};

module.exports = { analyze };
