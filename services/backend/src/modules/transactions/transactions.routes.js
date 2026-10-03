/*
|--------------------------------------------------------------------------
| TRANSACTIONS ROUTES  →  /api/transactions
|--------------------------------------------------------------------------
*/

const express = require("express");

const repository = require("./transactions.repository");
const asyncHandler = require("../../lib/async-handler");
const { sendSuccess } = require("../../lib/response");
const { requireAuth, requireRole } = require("../../middleware/auth");
const { userRole } = require("../../config/constants");
const { AuthorizationError } = require("../../lib/errors");

const router = express.Router();

router.use(requireAuth());

/**
 * GET /api/transactions/my
 * Collector earnings ledger (and recycler settlement list).
 */
router.get(
  "/my",
  requireRole(userRole.COLLECTOR, userRole.RECYCLER, userRole.ADMIN),
  asyncHandler(async (req, res) => {
    let transactions = [];

    if (req.user.role === userRole.COLLECTOR || req.user.role === userRole.ADMIN) {
      transactions = await repository.listForCollector(req.user.id);
    } else if (req.user.role === userRole.RECYCLER) {
      if (!req.user.recyclerId) {
        throw new AuthorizationError(
          "Recycler profile is required to view transactions."
        );
      }
      transactions = await repository.listForRecycler(req.user.recyclerId);
    }

    sendSuccess(res, {
      data: { transactions, count: transactions.length },
      extra: { transactions, count: transactions.length },
    });
  })
);

module.exports = router;
