/*
|--------------------------------------------------------------------------
| RATES REPOSITORY
|--------------------------------------------------------------------------
| The rate card. A rate update never overwrites the old row: the previous
| rate is closed off with valid_to and a new row is opened. That keeps every
| settled transaction explainable.
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne, insertOne, transaction } = require("../../db/query");

function toRate(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.public_id,
    material: row.material_id,
    materialId: row.material_id,
    displayName: row.display_name,
    category: row.category,
    ratePerKg: Number(row.rate_per_kg),
    // The dashboard's Rate type declares `unit`, and the deployed rate board
    // renders the rupee sign from it.
    unit: row.unit,
    region: row.region,
    source: row.source,
    isActive: row.is_active,
    validFrom: row.valid_from,
    validTo: row.valid_to,
    updatedAt: row.updated_at,
  };
}

const SELECT_CURRENT = `
  SELECT
    r.public_id,
    r.material_id,
    r.region,
    r.rate_per_kg,
    r.unit,
    r.source,
    r.is_active,
    r.valid_from,
    r.valid_to,
    r.updated_at,
    m.display_name,
    m.category
  FROM material_rates r
  JOIN materials m ON m.id = r.material_id
`;

async function listCurrent({ region = "IN-MH", client } = {}) {
  const rows = await queryRows(
    `${SELECT_CURRENT}
     WHERE r.is_active AND r.valid_to IS NULL AND r.region = $1
     ORDER BY m.category, m.display_name`,
    [region],
    { client, label: "rates:listCurrent" }
  );

  return rows.map(toRate);
}

async function findCurrentByPublicId(publicId, { region = "IN-MH", client } = {}) {
  const row = await queryOne(
    `${SELECT_CURRENT}
     WHERE r.public_id = $1 AND r.is_active AND r.valid_to IS NULL AND r.region = $2`,
    [publicId, region],
    { client, label: "rates:findCurrent" }
  );

  return toRate(row);
}

/**
 * The rate in force for a material at a point in time, used when explaining
 * a historical settlement.
 */
async function findRateAt(materialId, at, { region = "IN-MH", client } = {}) {
  const row = await queryOne(
    `${SELECT_CURRENT}
     WHERE r.material_id = $1
       AND r.region = $2
       AND r.valid_from <= $3
       AND (r.valid_to IS NULL OR r.valid_to > $3)
     ORDER BY r.valid_from DESC
     LIMIT 1`,
    [materialId, region, at],
    { client, label: "rates:findRateAt" }
  );

  return toRate(row);
}

async function history(publicId, { client } = {}) {
  const rows = await queryRows(
    `${SELECT_CURRENT}
     WHERE r.public_id = $1
     ORDER BY r.valid_from DESC`,
    [publicId],
    { client, label: "rates:history" }
  );

  return rows.map(toRate);
}

/**
 * Close the current rate and open a new one, in one transaction so the card
 * is never observed with two active rates for the same material.
 */
async function updateRate(publicId, { ratePerKg, source = "ADMIN", createdBy = null }) {
  return transaction(async (client) => {
    const current = await queryOne(
      `SELECT * FROM material_rates
       WHERE public_id = $1 AND is_active AND valid_to IS NULL
       FOR UPDATE`,
      [publicId],
      { client, label: "rates:lockCurrent" }
    );

    if (!current) {
      return null;
    }

    await queryRows(
      `UPDATE material_rates
       SET is_active = FALSE, valid_to = NOW()
       WHERE id = $1`,
      [current.id],
      { client, label: "rates:closeCurrent" }
    );

    await insertOne(
      "material_rates",
      {
        public_id: current.public_id,
        material_id: current.material_id,
        region: current.region,
        rate_per_kg: ratePerKg,
        unit: current.unit,
        source,
        is_active: true,
        valid_from: new Date(),
        valid_to: null,
        created_by: createdBy,
      },
      { client, label: "rates:openNew" }
    );

    const fresh = await queryOne(
      `${SELECT_CURRENT}
       WHERE r.public_id = $1 AND r.is_active AND r.valid_to IS NULL`,
      [publicId],
      { client, label: "rates:readNew" }
    );

    return toRate(fresh);
  });
}

module.exports = {
  listCurrent,
  findCurrentByPublicId,
  findRateAt,
  history,
  updateRate,
  toRate,
};