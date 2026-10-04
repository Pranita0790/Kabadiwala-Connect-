/*
| Reassign the collector PIN lot (6f8da380-…) from Harsh's org to
| Green Earth Recyclers Pune so it appears on that website session.
*/
const { getPool, closePool } = require("../src/db/pool");

const LOT_CLIENT = "6f8da380-388d-4a42-aff5-ae3b5e257eab";

async function main() {
  const pool = await getPool();
  const green = await pool.query(
    `SELECT id FROM recycler_profiles
     WHERE organisation_name = 'Green Earth Recyclers Pune'
     LIMIT 1`
  );
  if (!green.rows[0]) throw new Error("Green Earth profile missing");

  const lot = await pool.query(
    `UPDATE lots
     SET recycler_id = $1,
         status = 'HANDOVER',
         updated_at = NOW()
     WHERE client_reference::text = $2
        OR public_id::text = $2
     RETURNING public_id, lot_number, status, recycler_id, client_reference`,
    [green.rows[0].id, LOT_CLIENT]
  );

  await pool.query(
    `UPDATE handovers h
     SET recycler_id = $1
     FROM lots l
     WHERE h.lot_id = l.id
       AND (l.client_reference::text = $2 OR l.public_id::text = $2)`,
    [green.rows[0].id, LOT_CLIENT]
  );

  console.log(JSON.stringify({ greenEarthId: green.rows[0].id, lot: lot.rows }, null, 2));
  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
