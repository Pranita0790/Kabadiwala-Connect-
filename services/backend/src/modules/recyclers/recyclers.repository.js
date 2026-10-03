/*
|--------------------------------------------------------------------------
| RECYCLERS REPOSITORY
|--------------------------------------------------------------------------
| Reads recycler_profiles (+ accepted materials) for collector matching.
|--------------------------------------------------------------------------
*/

const { queryRows } = require("../../db/query");

function toRecyclerDto(row) {
  const accepted = row.accepted_materials
    ? String(row.accepted_materials)
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    : [];

  return {
    id: row.id,
    name: row.organisation_name,
    organisationName: row.organisation_name,
    address: row.address || [row.city, row.region].filter(Boolean).join(", "),
    city: row.city,
    region: row.region,
    acceptedCategories: accepted,
    accepted_categories: accepted.join(","),
    distanceKm: 0,
    distance_km: 0,
    isAuthorized: Boolean(row.is_authorized),
    is_authorized: Boolean(row.is_authorized),
    rating: row.rating === null ? 4.5 : Number(row.rating),
    contactPhone: row.contact_phone,
    contact_phone: row.contact_phone,
    latitude: row.latitude === null ? 0 : Number(row.latitude),
    longitude: row.longitude === null ? 0 : Number(row.longitude),
    indicativePrice: null,
    indicative_price: null,
    unit: "kg",
    isDemo: false,
    is_demo: false,
  };
}

/**
 * @param {{ categoryId?: string }} filters
 */
async function list({ categoryId } = {}) {
  const params = [];
  let materialFilter = "";

  if (categoryId && categoryId !== "all") {
    params.push(categoryId);
    materialFilter = `
      AND (
        rp.accepts_mixed = TRUE
        OR EXISTS (
          SELECT 1 FROM recycler_accepted_materials ram
          WHERE ram.recycler_id = rp.id AND ram.material_id = $${params.length}
        )
      )
    `;
  }

  const rows = await queryRows(
    `SELECT
       rp.id,
       rp.organisation_name,
       rp.address,
       rp.city,
       rp.region,
       rp.latitude,
       rp.longitude,
       rp.contact_phone,
       rp.is_authorized,
       rp.rating,
       rp.accepts_mixed,
       (
         SELECT string_agg(ram.material_id, ',' ORDER BY ram.material_id)
         FROM recycler_accepted_materials ram
         WHERE ram.recycler_id = rp.id
       ) AS accepted_materials
     FROM recycler_profiles rp
     WHERE rp.is_active = TRUE
     ${materialFilter}
     ORDER BY rp.is_authorized DESC, rp.organisation_name ASC`,
    params,
    { label: "recyclers:list" }
  );

  return rows.map(toRecyclerDto);
}

module.exports = { list, toRecyclerDto };
