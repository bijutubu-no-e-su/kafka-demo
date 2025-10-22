import cors from "cors";
import express from "express";
import path from "path";
import pg from "pg";
import { fileURLToPath } from "url";

const {
  PGHOST = "pg",
  PGPORT = "5432",
  PGDATABASE = "demo",
  PGUSER = "postgres",
  PGPASSWORD = "postgres",
  PORT = "8080",
} = process.env;

const app = express();
app.use(cors());

// public配信 (将来UIのビルド成果物を置く場合)
const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.use(express.static(path.join(__dirname, "public")));

const pool = new pg.Pool({
  host: PGHOST,
  port: +PGPORT,
  database: PGDATABASE,
  user: PGUSER,
  password: PGPASSWORD,
});

async function getColor(table, id = 1) {
  try {
    console.log(`[getColor] Querying table: ${table}, id: ${id}`);
    const { rows } = await pool.query(
      `SELECT color FROM public.${table} WHERE id = $1 LIMIT 1`,
      [id]
    );
    console.log(`[getColor] Result for ${table}:`, rows);
    return rows[0]?.color || "gray";
  } catch (error) {
    console.error(`[getColor] Error querying ${table}:`, error);
    return "gray";
  }
}

// 全パネルの色を一度に取得
app.get("/api/panels", async (req, res) => {
  try {
    console.log("[/api/panels] Fetching all panel colors...");
    const [a, b, c, d] = await Promise.all([
      getColor("a_panel", 1),
      getColor("b_panel", 1),
      getColor("c_panel", 1),
      getColor("d_panel", 1),
    ]);
    console.log("[/api/panels] Result:", { a, b, c, d });
    res.json({ a, b, c, d });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "internal_error" });
  }
});

// 個別パネルの色を取得
app.get("/api/panel/:name", async (req, res) => {
  try {
    const map = { a: "a_panel", b: "b_panel", c: "c_panel", d: "d_panel" };
    const tbl = map[req.params.name?.toLowerCase()];
    if (!tbl) return res.status(404).json({ error: "unknown panel" });
    const color = await getColor(tbl, 1);
    res.json({ table: tbl, id: 1, color });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "internal_error" });
  }
});

// ksqlDB統計データを取得
app.get("/api/stats", async (req, res) => {
  try {
    // ksqlDBに統計クエリを送信
    const colorStatsResponse = await fetch("http://ksqldb:8088/query", {
      method: "POST",
      headers: {
        "Content-Type": "application/vnd.ksql.v1+json",
        Accept: "application/vnd.ksql.v1+json",
      },
      body: JSON.stringify({
        ksql: "SELECT color, total_changes FROM COLOR_STATS;",
      }),
    });

    const latestUpdatesResponse = await fetch("http://ksqldb:8088/query", {
      method: "POST",
      headers: {
        "Content-Type": "application/vnd.ksql.v1+json",
        Accept: "application/vnd.ksql.v1+json",
      },
      body: JSON.stringify({
        ksql: "SELECT panel_name, current_color FROM LATEST_UPDATES;",
      }),
    });

    const colorStats = await colorStatsResponse.json();
    const latestUpdates = await latestUpdatesResponse.json();

    res.json({
      colorStats: colorStats,
      latestUpdates: latestUpdates,
      timestamp: new Date().toISOString(),
    });
  } catch (e) {
    console.error("[stats] Error:", e);
    res.status(500).json({ error: "Failed to fetch stats" });
  }
});

// デバッグ用: データベース内容確認
app.get("/api/debug/tables", async (req, res) => {
  try {
    console.log("[debug] Checking all table contents...");
    const queries = [
      "SELECT * FROM a_panel",
      "SELECT * FROM b_panel",
      "SELECT * FROM c_panel",
      "SELECT * FROM d_panel",
    ];

    const results = {};
    for (const query of queries) {
      const tableName = query.split(" ")[2]; // Extract table name
      try {
        const { rows } = await pool.query(query);
        results[tableName] = rows;
        console.log(`[debug] ${tableName}:`, rows);
      } catch (err) {
        console.error(`[debug] Error querying ${tableName}:`, err.message);
        results[tableName] = { error: err.message };
      }
    }

    res.json(results);
  } catch (e) {
    console.error("[debug] Error:", e);
    res.status(500).json({ error: "Debug failed" });
  }
});

app.listen(+PORT, () => {
  console.log(`[web] listening on port ${PORT}`);
});
