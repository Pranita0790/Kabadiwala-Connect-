/*
| Authorize the local demo recycler so collector matching shows it as verified.
| Usage: node scripts/authorize-demo-recycler.js
*/
const { getPool, closePool } = require("../src/db/pool");

async function main() {
  const pool = await getPool();
  const result = await pool.query(
    `UPDATE recycler_profiles
     SET is_authorized = TRUE,
         accepts_mixed = TRUE,
         is_active = TRUE
     WHERE organisation_name = $1
     RETURNING id, organisation_name, is_authorized, accepts_mixed`,
    ["Green Earth Recyclers Pune"]
  );
  console.log(JSON.stringify(result.rows, null, 2));
  await closePool();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
