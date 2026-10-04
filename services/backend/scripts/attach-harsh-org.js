/*
| Attach an authorized org profile for Harsh Alkar so collector matching
| shows the website org. Role stays COLLECTOR so user-app vendors still work.
*/
const { getPool, closePool } = require("../src/db/pool");

async function main() {
  const pool = await getPool();
  const user = await pool.query(
    `SELECT id, full_name, phone, role FROM users
     WHERE phone IN ('+918591274978', '8591274978')
     LIMIT 1`
  );
  if (!user.rows[0]) {
    throw new Error("Harsh Alkar user not found");
  }
  const u = user.rows[0];
  const existing = await pool.query(
    `SELECT id FROM recycler_profiles WHERE user_id = $1`,
    [u.id]
  );
  if (existing.rows[0]) {
    await pool.query(
      `UPDATE recycler_profiles
       SET organisation_name = 'Harsh Alkar Recycling Hub',
           is_authorized = TRUE,
           is_active = TRUE,
           accepts_mixed = TRUE,
           city = COALESCE(city, 'Pune'),
           region = COALESCE(region, 'Maharashtra'),
           contact_phone = COALESCE(contact_phone, $2)
       WHERE id = $1`,
      [existing.rows[0].id, u.phone]
    );
    console.log("Updated profile", existing.rows[0].id);
  } else {
    const inserted = await pool.query(
      `INSERT INTO recycler_profiles
         (user_id, organisation_name, address, city, region,
          is_authorized, is_active, accepts_mixed, contact_phone)
       VALUES ($1,$2,$3,$4,$5,TRUE,TRUE,TRUE,$6)
       RETURNING id, organisation_name`,
      [
        u.id,
        "Harsh Alkar Recycling Hub",
        "Pune",
        "Pune",
        "Maharashtra",
        u.phone,
      ]
    );
    console.log("Created profile", inserted.rows[0]);
  }

  const list = await pool.query(
    `SELECT organisation_name, is_authorized, u.phone, u.role
     FROM recycler_profiles rp
     JOIN users u ON u.id = rp.user_id
     ORDER BY organisation_name`
  );
  console.log(JSON.stringify(list.rows, null, 2));
  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
