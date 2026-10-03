/*
|--------------------------------------------------------------------------
| PRICE ALERTS SERVICE
|--------------------------------------------------------------------------
*/

const repository = require("./price-alerts.repository");
const ratesService = require("../rates/rates.service");
const materialsRepository = require("../materials/materials.repository");
const { NotFoundError, ValidationError } = require("../../lib/errors");

async function create(userId, input) {
  const { materialId, targetRatePerKg, direction, region } = input;

  // Reject an alert for a material that is not in the catalogue: otherwise
  // it could never be evaluated.
  const material = await materialsRepository.findById(materialId);

  if (!material) {
    throw new ValidationError(
      `Unknown material "${materialId}". Send GET /api/materials for valid ids.`,
      { materialId }
    );
  }

  // Guard against a target that is already satisfied, which would create an
  // alert that fires on the very next rate check.
  const current = await ratesService
    .calculateIndicativeValue({ materialId, weightKg: 1, region })
    .catch(() => null);

  if (
    current?.ratePerKg != null &&
    ((direction === "ABOVE" && current.ratePerKg >= targetRatePerKg) ||
      (direction === "BELOW" && current.ratePerKg <= targetRatePerKg))
  ) {
    throw new ValidationError(
      `The current rate is already ₹${current.ratePerKg}/kg, which satisfies this alert.`,
      {
        currentRatePerKg: current.ratePerKg,
        targetRatePerKg,
        direction,
      }
    );
  }

  return repository.create({
    userId,
    materialId,
    region,
    targetRatePerKg,
    direction,
  });
}

async function list(userId, options) {
  const [alerts, total] = await Promise.all([
    repository.listForUser(userId, options),
    repository.countForUser(userId),
  ]);

  return { alerts, total };
}

async function remove(userId, publicId) {
  const existing = await repository.findOwnedByPublicId(userId, publicId);

  if (!existing) {
    throw new NotFoundError("Price alert not found");
  }

  return repository.deactivate(userId, publicId);
}

module.exports = { create, list, remove };