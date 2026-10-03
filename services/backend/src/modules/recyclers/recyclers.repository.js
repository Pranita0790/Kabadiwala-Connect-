/*
|--------------------------------------------------------------------------
| RECYCLERS REPOSITORY
|--------------------------------------------------------------------------
| Reads recycler_profiles (+ accepted materials) for collector matching.
|--------------------------------------------------------------------------
*/

const { queryRows, queryOne } = require("../../db/query");

function toRecyclerDto(row) {
  const accepted = row.accepted_materials
    ? String(row.accepted_materials)
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    : [];

  // Until accepted-materials rows are curated, an empty list means the
  // facility accepts mixed/general e-waste so collector matching still works.
  const categories =
    accepted.length > 0 ? accepted : ["mixed", "pcb", "battery", "cable", "crt", "lcd_panel"];

  return {
    id: row.id,
    name: row.organisation_name,
    organisationName: row.organisation_name,
    address: row.address || [row.city, row.region].filter(Boolean).join(", ") || "India",
    city: row.city,
    region: row.region,
    acceptedCategories: categories,
    accepted_categories: categories.join(","),
    distanceKm: 0,
    distance_km: 0,
    isAuthorized: Boolean(row.is_authorized),
    is_authorized: Boolean(row.is_authorized),
    rating: row.rating === null ? 4.5 : Number(row.rating),
    contactPhone: row.contact_phone,
    contact_phone: row.contact_phone,
    latitude: row.latitude === null ? 0 : Number(row.latitude),
    longitude: row.longitude === null ? 0 : Number(row.longitude),
    indicativePrice: 250,
    indicative_price: 250,
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
       COALESCE(rp.contact_phone, u.phone) AS contact_phone,
       rp.is_authorized,
       rp.rating,
       rp.accepts_mixed,
       (
         SELECT string_agg(ram.material_id, ',' ORDER BY ram.material_id)
         FROM recycler_accepted_materials ram
         WHERE ram.recycler_id = rp.id
       ) AS accepted_materials
     FROM recycler_profiles rp
     LEFT JOIN users u ON u.id = rp.user_id
     WHERE rp.is_active = TRUE
     ${materialFilter}
     ORDER BY rp.is_authorized DESC, rp.organisation_name ASC`,
    params,
    { label: "recyclers:list" }
  );

  return rows.map(toRecyclerDto);
}

async function findIdByOrganisationName(name) {
  if (!name || !String(name).trim()) return null;
  const row = await queryOne(
    `SELECT id
     FROM recycler_profiles
     WHERE is_active = TRUE
       AND LOWER(organisation_name) = LOWER($1)
     ORDER BY is_authorized DESC
     LIMIT 1`,
    [String(name).trim()],
    { label: "recyclers:findByName" }
  );
  return row?.id || null;
}

module.exports = { list, toRecyclerDto, findIdByOrganisationName };
