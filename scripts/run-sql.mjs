import { readFileSync } from "fs";
import pg from "pg";

const file = process.argv[2];
if (!file) {
  console.error("Usage: node scripts/run-sql.mjs <file.sql>");
  process.exit(1);
}

const raw = process.env.POSTGRES_URL_NON_POOLING || process.env.POSTGRES_URL;
const url = new URL(raw);
url.searchParams.delete("sslmode");
url.searchParams.delete("supa");

const client = new pg.Client({
  connectionString: url.toString(),
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  await client.query(readFileSync(file, "utf8"));
  console.log("[v0] Applied", file);
} finally {
  await client.end();
}
