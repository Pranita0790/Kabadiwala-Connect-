/*
| Ensure every RECYCLER user has an active authorized profile so collector
| matching and the dashboard org label stay in sync.
*/
const { getPool, closePool } = require("../src/db/pool");

async function main() {
  const pool = await getPool();

  const users = await pool.query(
    `SELECT u.id, u.public_id, u.full_name, u.phone, u.role,
            rp.id AS profile_id, rp.organisation_name, rp.is_authorized, rp.is_active
     FROM users u
     LEFT JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.role = 'RECYCLER'
     ORDER BY u.created_at`
  );
  console.log("recyclers_before:", JSON.stringify(users.rows, null, 2));

  for (const row of users.rows) {
    if (row.profile_id) {
      await pool.query(
        `UPDATE recycler_profiles
         SET is_authorized = TRUE,
             is_active = TRUE,
             accepts_mixed = TRUE,
             organisation_name = COALESCE(NULLIF(TRIM(organisation_name), ''), $2)
         WHERE id = $1`,
        [row.profile_id, `${row.full_name || "Recycler"} Organisation`]
      );
      continue;
    }

    await pool.query(
      `INSERT INTO recycler_profiles
         (user_id, organisation_name, address, city, region, is_authorized, is_active, accepts_mixed)
       VALUES ($1, $2, $3, $4, $5, TRUE, TRUE, TRUE)`,
      [
        row.id,
        row.full_name ? `${row.full_name} Organisation` : "Recycler Organisation",
        "Pune",
        "Pune",
        "Maharashtra",
      ]
    );
  }

  const recyclers = await pool.query(
    `SELECT rp.organisation_name, rp.is_authorized, rp.is_active, u.phone, u.public_id
     FROM recycler_profiles rp
     JOIN users u ON u.id = rp.user_id
     ORDER BY rp.organisation_name`
  );
  console.log("profiles_after:", JSON.stringify(recyclers.rows, null, 2));
  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
