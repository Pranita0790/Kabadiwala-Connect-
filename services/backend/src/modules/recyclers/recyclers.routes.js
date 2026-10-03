/*
|--------------------------------------------------------------------------
| RECYCLERS ROUTES  →  /api/recyclers
|--------------------------------------------------------------------------
| Directory used by the collector matching screen. Optional auth so a
| signed-in collector can still load the list; unauthenticated reads are
| allowed because profiles contain organisation contact data only.
|--------------------------------------------------------------------------
*/

const express = require("express");
const { z } = require("zod");

const repository = require("./recyclers.repository");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { validate, validatedQuery } = require("../../middleware/validate");
const { optionalAuth } = require("../../middleware/auth");

const router = express.Router();

const listSchema = {
  query: z
    .object({
      categoryId: z.string().trim().max(64).optional(),
    })
    .strip(),
};

// GET /api/recyclers
router.get(
  "/",
  optionalAuth(),
  validate(listSchema),
  asyncHandler(async (req, res) => {
    const { categoryId } = validatedQuery(req);
    const recyclers = await repository.list({ categoryId });

    sendSuccess(res, {
      data: { recyclers, count: recyclers.length },
      extra: { recyclers, count: recyclers.length },
    });
  })
);

module.exports = router;
