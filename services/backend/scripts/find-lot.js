const axios = require("axios");
const { getPool, closePool } = require("../src/db/pool");

const LOT_ID = "6f8da380-388d-4a42-aff5-ae3b5e257eab";
const HANDOVER_SHORT = "B1EEE0C5";

async function main() {
  const pool = await getPool();
  const lots = await pool.query(
    `SELECT l.public_id, l.client_reference, l.lot_number, l.status, l.weight_kg,
            l.material_id, l.recycler_id, rp.organisation_name,
            u.full_name AS collector_name
     FROM lots l
     LEFT JOIN recycler_profiles rp ON rp.id = l.recycler_id
     LEFT JOIN users u ON u.id = l.collector_id
     WHERE l.public_id::text = $1
        OR l.client_reference::text = $1
        OR l.id::text = $1
        OR l.lot_number ILIKE $2`,
    [LOT_ID, `%${HANDOVER_SHORT}%`]
  );
  console.log("local_lots:", JSON.stringify(lots.rows, null, 2));

  const handovers = await pool.query(
    `SELECT h.public_id, h.client_reference, h.status, h.lot_id, h.recycler_id,
            h.weight_kg, h.material_category
     FROM handovers h
     WHERE h.client_reference::text ILIKE $1
        OR h.public_id::text ILIKE $1
        OR h.client_reference::text = $2
        OR h.lot_id::text IN (
          SELECT id::text FROM lots
          WHERE public_id::text = $2 OR client_reference::text = $2
        )`,
    [`%${HANDOVER_SHORT}%`, LOT_ID]
  );
  console.log("local_handovers:", JSON.stringify(handovers.rows, null, 2));

  // Any recent 5kg mixed lots
  const recent = await pool.query(
    `SELECT l.public_id, l.client_reference, l.lot_number, l.status, l.weight_kg,
            l.created_at, rp.organisation_name
     FROM lots l
     LEFT JOIN recycler_profiles rp ON rp.id = l.recycler_id
     WHERE l.weight_kg = 5
     ORDER BY l.created_at DESC
     LIMIT 10`
  );
  console.log("recent_5kg:", JSON.stringify(recent.rows, null, 2));

  await closePool();

  // Green Earth recycler feed
  try {
    const login = await axios.post("http://127.0.0.1:5000/api/auth/login", {
      identifier: "9876500001",
      password: "Recycler1a",
    });
    const token = login.data.data.accessToken;
    const feed = await axios.get("http://127.0.0.1:5000/api/lots?limit=100", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const list = feed.data.data?.lots || feed.data.lots || [];
    const match = list.filter(
      (l) =>
        l.id === LOT_ID ||
        l.clientReference === LOT_ID ||
        l.client_reference === LOT_ID ||
        String(l.id || "").toLowerCase().includes("6f8da380")
    );
    console.log(
      "green_earth_feed_count",
      list.length,
      "match",
      match.map((l) => ({
        id: l.id,
        lotNumber: l.lotNumber,
        status: l.status,
        statusLabel: l.statusLabel,
        recyclerId: l.recyclerId,
        clientReference: l.clientReference,
      }))
    );
    console.log(
      "handover_or_accepted",
      list
        .filter((l) => ["HANDOVER", "ACCEPTED", "Handover", "Accepted"].includes(l.status) || ["Handover", "Accepted"].includes(l.statusLabel))
        .map((l) => ({
          id: l.id,
          lotNumber: l.lotNumber || l.lot_number,
          status: l.status,
          statusLabel: l.statusLabel,
          weight: l.weightKg,
          collector: l.collector,
        }))
    );
  } catch (e) {
    console.log("feed_err", e.response?.data || e.message);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
