import { Kafka } from 'kafkajs'
import pg from 'pg'

const {
  KAFKA_BROKER = 'kafka:9092',
  GROUP_ID = 'db-writer',
  TOPICS = 'b_panel_topic,c_panel_topic,d_panel_topic',
  PGHOST = 'pg',
  PGPORT = '5432',
  PGDATABASE = 'demo',
  PGUSER = 'postgres',
  PGPASSWORD = 'postgres',
} = process.env

const kafka = new Kafka({ clientId: 'db-writer', brokers: [KAFKA_BROKER] })
const consumer = kafka.consumer({ groupId: GROUP_ID })

const pool = new pg.Pool({
  host: PGHOST,
  port: +PGPORT,
  database: PGDATABASE,
  user: PGUSER,
  password: PGPASSWORD,
})

function topicToTable(topic) {
  const t = topic.toLowerCase()
  if (t === 'b_panel_topic') return 'b_panel'
  if (t === 'c_panel_topic') return 'c_panel'
  if (t === 'd_panel_topic') return 'd_panel'
  return null
}

async function upsert(table, id, color) {
  const sql = `INSERT INTO public.${table} (id, color)
               VALUES ($1, $2)
               ON CONFLICT (id) DO UPDATE SET color=EXCLUDED.color;`
  await pool.query(sql, [id, color])
}

function normalizeColor(v) {
  return v?.color ?? v?.COLOR ?? v?.Color ?? null
}
function normalizeId(v) {
  return v?.id ?? v?.ID ?? null
}

;(async () => {
  const topics = TOPICS.split(',')
    .map((s) => s.trim())
    .filter(Boolean)
  console.log('[writer] starting. topics:', topics)
  await consumer.connect()
  for (const t of topics) await consumer.subscribe({ topic: t, fromBeginning: true })

  await consumer.run({
    eachMessage: async ({ topic, message }) => {
      try {
        const table = topicToTable(topic)
        if (!table) return
        const str = message.value?.toString()
        if (!str) return
        const json = JSON.parse(str)
        const id = normalizeId(json)
        const color = normalizeColor(json)
        if (id == null || !color) return
        await upsert(table, id, color)
        console.log(`[writer] ${topic} -> ${table} upsert`, { id, color })
      } catch (e) {
        console.error('[writer] error:', e)
      }
    },
  })
})()
