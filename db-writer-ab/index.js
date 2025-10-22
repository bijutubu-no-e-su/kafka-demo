import { Kafka, logLevel } from 'kafkajs'
import pg from 'pg'

const {
  KAFKA_BROKER = 'kafka:9092',
  GROUP_ID = 'db-writer',
  TOPIC = '', // ← 各サービスで必須設定に（後で推論も可）
  DEST_TABLE = '', // ← 未指定なら TOPIC から推論
  COLOR_MAP_JSON = '{}',
  PGHOST = 'pg',
  PGPORT = '5432',
  PGDATABASE = 'demo',
  PGUSER = 'postgres',
  PGPASSWORD = 'postgres',
} = process.env

// 1) 変換マップ
let COLOR_MAP = {}
try {
  COLOR_MAP = JSON.parse(COLOR_MAP_JSON)
} catch {
  COLOR_MAP = {}
}

// 2) TOPIC→推論 DEST のマップ（必要ならここを調整）
const inferDestFromTopic = (t) => {
  const s = (t || '').toLowerCase()
  if (s.endsWith('.a_panel')) return 'b_panel' // A→B
  if (s.endsWith('.b_panel')) return 'c_panel' // B→C
  if (s.endsWith('.c_panel')) return 'd_panel' // C→D
  return null
}

// 3) 最終的な行き先テーブルを決定
const INFERRED_DEST = inferDestFromTopic(TOPIC)
const RESOLVED_DEST = (DEST_TABLE || INFERRED_DEST || '').toLowerCase()

if (!TOPIC) {
  console.error('[writer] FATAL: TOPIC is required')
  process.exit(1)
}
if (!RESOLVED_DEST) {
  console.error('[writer] FATAL: DEST_TABLE not set and cannot infer from TOPIC:', TOPIC)
  process.exit(1)
}
// 不一致ガード：ENVで明示されたDESTと推論が食い違う時は警告（誤配線防止）
if (DEST_TABLE && INFERRED_DEST && DEST_TABLE.toLowerCase() !== INFERRED_DEST) {
  console.warn(
    `[writer] WARNING: DEST_TABLE(${DEST_TABLE}) != inferred(${INFERRED_DEST}) from TOPIC(${TOPIC})`
  )
}

const kafka = new Kafka({
  clientId: `db-writer-${RESOLVED_DEST}`,
  brokers: [KAFKA_BROKER],
  logLevel: logLevel.INFO,
  retry: { initialRetryTime: 300, factor: 1.8, retries: 20 },
})
const consumer = kafka.consumer({ groupId: `${GROUP_ID}-${RESOLVED_DEST}` })

const pool = new pg.Pool({
  host: PGHOST,
  port: +PGPORT,
  database: PGDATABASE,
  user: PGUSER,
  password: PGPASSWORD,
})

// Debezium & 素JSONどちらも拾える抽出
function extractIdColor(msgObj) {
  const p = msgObj?.payload
  const after = p?.after
  if (after && after.id != null && after.color)
    return { id: after.id, color: after.color, op: p?.op }
  if (msgObj?.id != null && msgObj?.color) return { id: msgObj.id, color: msgObj.color }
  const a2 = msgObj?.AFTER || msgObj?.after
  if (a2 && a2.id != null && a2.color) return { id: a2.id, color: a2.color }
  return null
}

const transformColor = (src) => COLOR_MAP[src] ?? src

async function upsert(table, id, color) {
  const sql = `
    INSERT INTO public.${table} (id, color)
    VALUES ($1, $2)
    ON CONFLICT (id) DO UPDATE SET color = EXCLUDED.color
  `
  await pool.query(sql, [id, color])
}

;(async () => {
  console.log('[writer] start', { TOPIC, DEST_TABLE: RESOLVED_DEST, COLOR_MAP })

  // 接続待ち（起動順レース対策）
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
  async function wait(fn, label) {
    for (let i = 1; i <= 60; i++) {
      try {
        return await fn()
      } catch (e) {
        console.error(`[retry ${label}] #${i}:`, e.message || e)
        await sleep(Math.min(1000 * i, 5000))
      }
    }
    throw new Error(`give up ${label}`)
  }

  await wait(() => consumer.connect(), 'kafka connect')
  await wait(() => consumer.subscribe({ topic: TOPIC, fromBeginning: true }), 'kafka subscribe')

  await consumer.run({
    eachMessage: async ({ topic, message }) => {
      try {
        if (!message.value) return
        const obj = JSON.parse(message.value.toString())
        const rec = extractIdColor(obj)
        if (!rec) return
        if (rec.op === 'd') return // delete skip

        // 追加ガード：TOPICとの対応が期待とズレてたら書き込まない
        const expected = inferDestFromTopic(topic)
        if (expected && expected !== RESOLVED_DEST) {
          console.error(
            `[writer] topic→dest mismatch: topic=${topic} expectedDest=${expected} but RESOLVED_DEST=${RESOLVED_DEST}; skip`
          )
          return
        }

        const newColor = transformColor(rec.color)
        await upsert(RESOLVED_DEST, rec.id, newColor)
        console.log(`[writer] ${topic} -> ${RESOLVED_DEST} upsert`, {
          id: rec.id,
          color: rec.color,
          newColor,
        })
      } catch (e) {
        console.error('[writer] error:', e)
      }
    },
  })
})().catch((e) => {
  console.error('[writer] fatal', e)
  process.exit(1)
})
