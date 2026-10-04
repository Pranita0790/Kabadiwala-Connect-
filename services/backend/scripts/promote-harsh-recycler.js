const { getPool, closePool } = require("../src/db/pool");

async function main() {
  const pool = await getPool();
  await pool.query(
    `UPDATE users SET role = 'RECYCLER' WHERE phone = '+918591274978'`
  );
  const result = await pool.query(
    `SELECT u.phone, u.role, rp.organisation_name, rp.id AS recycler_id
     FROM users u
     JOIN recycler_profiles rp ON rp.user_id = u.id
     WHERE u.phone = '+918591274978'`
  );
  console.log(JSON.stringify(result.rows, null, 2));
  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
