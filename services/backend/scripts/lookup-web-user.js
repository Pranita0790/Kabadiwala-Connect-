const { getPool, closePool } = require("../src/db/pool");

async function main() {
  const pool = await getPool();
  const result = await pool.query(
    `SELECT u.id, u.public_id, u.full_name, u.phone, u.role,
            rp.organisation_name, rp.id AS recycler_profile_id
     FROM users u
     LEFT JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.id::text = $1
        OR u.public_id::text = $1
        OR u.phone LIKE $2
     ORDER BY u.created_at`,
    ["fd62b1e8-d3e4-4212-b9c7-fbd5bbe2ca35", "%8591274978%"]
  );
  console.log(JSON.stringify(result.rows, null, 2));
  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
