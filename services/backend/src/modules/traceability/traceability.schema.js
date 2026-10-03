/*
|--------------------------------------------------------------------------
| TRACEABILITY SCHEMAS
|--------------------------------------------------------------------------
*/

const { z } = require("zod");

const byId = {
  params: z.object({ lotId: z.string().trim().min(1).max(64) }),
};

const list = {
  query: z
    .object({
      search: z.string().trim().max(200).optional(),
      status: z.string().trim().max(32).optional(),
      page: z.coerce.number().int().positive().optional(),
      pageSize: z.coerce.number().int().positive().optional(),
      limit: z.coerce.number().int().positive().optional(),
    })
    .strip(),
};

module.exports = { byId, list };
