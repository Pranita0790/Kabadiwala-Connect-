const path = require("node:path");
require("dotenv").config({
  path: path.resolve(__dirname, "../../../.env"),
});

const { Client } = require("pg");
const config = require("../src/config/env");

async function main() {
  const client = new Client({
    host: config.database.host,
    port: config.database.port,
    database: "postgres",
    user: config.database.user,
    password: String(config.database.password || ""),
  });

  await client.connect();

  const existing = await client.query(
    "SELECT 1 FROM pg_database WHERE datname = $1",
    [config.database.name]
  );

  if (existing.rows.length === 0) {
    await client.query(`CREATE DATABASE "${config.database.name}"`);
    console.log(`Created database ${config.database.name}`);
  } else {
    console.log(`Database ${config.database.name} already exists`);
  }

  await client.end();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
