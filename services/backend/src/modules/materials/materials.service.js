/*
|--------------------------------------------------------------------------
| MATERIALS SERVICE
|--------------------------------------------------------------------------
*/

const repository = require("./materials.repository");
const { NotFoundError } = require("../../lib/errors");
const { deployedModel } = require("../../config/constants");

async function list(options = {}) {
  return repository.list(options);
}

async function get(id) {
  const material = await repository.findById(id);

  if (!material) {
    throw new NotFoundError(`Unknown material "${id}"`, {
      materialId: id,
    });
  }

  return material;
}

/**
 * The classes the deployed model can actually predict, so a client does not
 * offer a collector a classification the model cannot produce.
 */
async function modelCapabilities() {
  return {
    modelVersion: deployedModel.modelVersion,
    confidenceThreshold: deployedModel.confidenceThreshold,
    supportedMaterials: deployedModel.supportedMaterials,
    // Materials in the catalogue that the model cannot predict are still
    // valid lot categories — they are simply entered manually.
    catalogueOnlyMaterials: (
      await repository.list()
    )
      .filter((material) => !material.isModelSupported)
      .map((material) => material.id),
  };
}

module.exports = { list, get, modelCapabilities };