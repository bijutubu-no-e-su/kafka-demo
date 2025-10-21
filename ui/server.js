import express from 'express'
import { Kafka } from 'kafkajs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()
const PORT = process.env.PORT || 3000

// Express アプリケーション。SSE エンドポイントと静的ファイル配信を担当します。

// ===== Kafka 接続設定 =====
// コンテナ内ではサービス名（kafka）で到達可能。ホストからアクセスする場合は localhost:29092 などを使う。
const KAFKA_BROKER = process.env.KAFKA_BROKER || 'kafka:9092'
// Kafka コンシューマグループ ID。複数 UI を立ち上げるときは同期の取り方に注意。
const GROUP_ID = process.env.KAFKA_GROUP_ID || 'ui-sse-group'
// 購読するトピック一覧。カンマ区切りで環境変数から渡せます。
const TOPICS = (process.env.TOPICS || 'pg.public.a_panel,b_panel_topic,c_panel_topic,d_panel_topic')
  .split(',')
  .map((s) => s.trim())

// kafkajs のクライアント設定
const kafka = new Kafka({
  clientId: 'ui-sse',
  brokers: [KAFKA_BROKER],
  // 多少のリトライ設定をしておく
  retry: { initialRetryTime: 300, retries: 8 },
})

// 最新状態（ここはメモリ上の簡易キャッシュ）。
// 現在は id=1 の単一行のみを追跡する設計。複数 id を扱う場合は Map やオブジェクトの入れ子にする。
const state = {
  A: { id: 1, color: 'unknown' },
  B: { id: 1, color: 'unknown' },
  C: { id: 1, color: 'unknown' },
  D: { id: 1, color: 'unknown' },
}

// 購読 → state更新 → ブロードキャスト
// Kafka コンシューマ（kafkajs）と、現在接続中の SSE クライアント集合
const consumer = kafka.consumer({ groupId: GROUP_ID })
const sseClients = new Set()

// 接続中の全 SSE クライアントへデータを送信するユーティリティ
function broadcast(payloadObj) {
  const data = `data: ${JSON.stringify(payloadObj)}\n\n`
  for (const res of sseClients) {
    // res.write は SSE の一行を送信する（Content-Type が text/event-stream）
    res.write(data)
  }
}

// メッセージから color を取り出すヘルパー
// ksqlDB や Debezium により JSON のキー名が大文字化されることがあるため、小文字・大文字両方を参照する
function normalizeColor(obj) {
  // Try several common locations produced by Debezium / ksqlDB / other connectors.
  // Messages often have the shape: { payload: { after: { id, color, ... } } }
  // or: { after: { id, color } } or a flat { id, color }.
  if (!obj) return 'unknown'
  const payload = obj?.payload?.after ?? obj?.after ?? obj
  return payload?.color ?? payload?.COLOR ?? payload?.Color ?? payload?.colour ?? 'unknown'
}

// トピック名から表示パネルの識別子に変換するユーティリティ
// 必要に応じてここにマッピングを追加する
// ★ 新旧トピック名どちらにも対応
function topicToPanel(topic) {
  const t = topic.toUpperCase()
  if (t === 'PG.PUBLIC.A_PANEL') return 'A'
  if (t === 'B_STREAM' || t === 'B_PANEL_TOPIC') return 'B'
  if (t === 'C_STREAM' || t === 'C_PANEL_TOPIC') return 'C'
  if (t === 'D_STREAM' || t === 'D_PANEL_TOPIC') return 'D'
  return null
}

async function runConsumer() {
  // Consumer を接続し、指定トピックを購読する
  await consumer.connect()
  for (const t of TOPICS) {
    // fromBeginning: true によりトピックの先頭から読み直す（デモ用途）
    await consumer.subscribe({ topic: t, fromBeginning: true })
  }

  // メッセージ処理の登録
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        // トピック名 → パネル識別（A/B/C/D）
        const panel = topicToPanel(topic)
        if (!panel) return

        // message.value は Buffer の場合があるので文字列化して JSON へ
        const str = message.value?.toString()
        if (!str) return
        const json = JSON.parse(str)

        // Many connector messages wrap the actual row under payload.after or after.
        const payload = json?.payload?.after ?? json?.after ?? json

        // Debug: log the received payload so we can inspect its shape
        console.log('[ui] recv', { topic, partition, offset: message.offset, payload })

        const color = normalizeColor(payload)
        // Check id in the same payload locations (id / ID)
        const id = payload?.id ?? payload?.ID ?? 1

        // Only surface the row with id=1 to the UI (this demo tracks a single row).
        if (id === 1) {
          state[panel] = { id, color }
          const msg = { panel, id, color, ts: Date.now() }
          // Debug: log what we broadcast to SSE clients
          console.log('[ui] broadcast', msg)
          broadcast(msg)
        }
      } catch (e) {
        // JSON パースや broadcast に失敗した場合はログに出す
        console.error('parse/broadcast error:', e)
      }
    },
  })
}

// ===== SSE エンドポイント =====
app.get('/sse', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.flushHeaders()

  // 接続直後に現状を送る
  res.write(`data: ${JSON.stringify({ type: 'snapshot', state })}\n\n`)

  sseClients.add(res)
  req.on('close', () => sseClients.delete(res))
})

// ===== React ビルドの静的配信 =====
app.use(express.static(path.join(__dirname, 'dist')))
app.get('*', (_, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'))
})

// 起動
app.listen(PORT, () => {
  console.log(`[ui] listening on http://localhost:${PORT}`)
  console.log('[ui] configured TOPICS:', TOPICS)
  // Kafka 消費を開始（接続失敗時は即終了せずリトライする）
  // 一時的な UNKNOWN_TOPIC_OR_PARTITION やメタデータ未同期などのエラーは
  // 環境起動順序の問題で発生しやすいため、ここで再試行を行います。
  const startConsumerWithRetry = async (attempt = 1) => {
    try {
      await runConsumer()
      console.log('[ui] Kafka consumer started')
    } catch (err) {
      console.error(`[ui] Kafka consumer failed (attempt=${attempt}):`, err)
      // exponential backoff (ms), capped to 30s
      const delay = Math.min(30000, 2000 * attempt)
      console.log(`[ui] retrying to start consumer in ${Math.round(delay / 1000)}s...`)
      setTimeout(() => startConsumerWithRetry(attempt + 1), delay)
    }
  }

  startConsumerWithRetry()
})
