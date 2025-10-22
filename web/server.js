import express from 'express'
import pg from 'pg'
import cors from 'cors'
import path from 'path'
import { fileURLToPath } from 'url'

const {
  PGHOST = 'pg',
  PGPORT = '5432',
  PGDATABASE = 'demo',
  PGUSER = 'postgres',
  PGPASSWORD = 'postgres',
  PORT = '8080',
} = process.env

const app = express()
app.use(cors())

// public配信 (将来UIのビルド成果物を置く場合)
const __dirname = path.dirname(fileURLToPath(import.meta.url))
app.use(express.static(path.join(__dirname, 'public')))

const pool = new pg.Pool({
  host: PGHOST,
  port: +PGPORT,
  database: PGDATABASE,
  user: PGUSER,
  password: PGPASSWORD,
})

async function getColor(table, id = 1) {
  const { rows } = await pool.query(`SELECT color FROM public.${table} WHERE id = $1 LIMIT 1`, [id])
  return rows[0]?.color || 'gray'
}

app.get('/api/panel/:name', async (req, res) => {
  try {
    const map = { a: 'a_panel', b: 'b_panel', c: 'c_panel', d: 'd_panel' }
    const tbl = map[req.params.name?.toLowerCase()]
    if (!tbl) return res.status(404).json({ error: 'unknown panel' })
    const color = await getColor(tbl, 1)
    res.json({ table: tbl, id: 1, color })
  } catch (e) {
    console.error(e)
    res.status(500).json({ error: 'internal_error' })
  }
})

app.listen(+PORT, () => {
  console.log(`[web] listening on port ${PORT}`)
})
