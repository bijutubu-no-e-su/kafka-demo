import React, { useEffect, useState } from 'react'

// 初期状態: A/B/C/D の各パネルのデフォルト値
const initial = {
  A: { id: 1, color: 'unknown' },
  B: { id: 1, color: 'unknown' },
  C: { id: 1, color: 'unknown' },
  D: { id: 1, color: 'unknown' },
}

// パネル表示コンポーネント
function Panel({ title, color }) {
  // 背景色に応じて文字色を自動で決定するヘルパーを使う
  const fg = getTextColor(color)
  return (
    <div className="panel" style={{ background: color, color: fg }}>
      <div className="label">{title}</div>
      <div className="value">{color}</div>
    </div>
  )
}

// 背景色に対して読みやすい文字色（黒/白）を返す簡易判定
// - 簡易な色名判定を行い、#RRGGBB の場合は YIQ 輝度判定で決める
function getTextColor(bg) {
  if (!bg) return '#000'
  const c = bg.toLowerCase()
  // 単純に暗い系の色名を白文字にする
  if (['black', 'navy', 'purple', 'maroon', 'gray', 'grey'].includes(c)) return '#fff'
  if (['white', 'yellow', 'pink', 'lightgray', 'lightgrey'].includes(c)) return '#000'
  // 16 進カラーコードを想定した判定
  if (c.startsWith('#') && (c.length === 7 || c.length === 4)) {
    let r, g, b
    if (c.length === 7) {
      r = parseInt(c.slice(1, 3), 16)
      g = parseInt(c.slice(3, 5), 16)
      b = parseInt(c.slice(5, 7), 16)
    } else {
      // 短縮形式 #RGB を #RRGGBB に展開してから解析
      r = parseInt(c[1] + c[1], 16)
      g = parseInt(c[2] + c[2], 16)
      b = parseInt(c[3] + c[3], 16)
    }
    // YIQ 輝度変換により黒白を決定
    const yiq = (r * 299 + g * 587 + b * 114) / 1000
    return yiq >= 128 ? '#000' : '#fff'
  }
  // それ以外は黒を返す（安全側）
  return '#000'
}

// メインアプリ
export default function App() {
  // React state: UI 表示用の現在状態と SSE 接続状態
  const [state, setState] = useState(initial)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    // サーバー側の /sse エンドポイントへ接続（SSE）
    const es = new EventSource('/sse')
    es.onopen = () => setConnected(true)
    es.onerror = () => setConnected(false)
    es.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data)
        // snapshot メッセージは現在の全状態を返す（初回接続時）
        if (msg?.type === 'snapshot' && msg.state) {
          setState(msg.state)
        } else if (msg?.panel) {
          // 個々のパネル更新を受け取ったら差分更新
          setState((prev) => ({ ...prev, [msg.panel]: { id: msg.id, color: msg.color } }))
        }
      } catch {}
    }
    return () => es.close()
  }, [])

  return (
    <div className="wrap">
      <h1>CDC Live Panels</h1>
      {/* 接続状態を表示 */}
      <div className={`status ${connected ? 'ok' : 'ng'}`}>
        {connected ? 'connected' : 'disconnected'}
      </div>
      <div className="grid">
        {/* 各パネルを描画 */}
        <Panel title="A" color={state.A.color} />
        <Panel title="B" color={state.B.color} />
        <Panel title="C" color={state.C.color} />
        <Panel title="D" color={state.D.color} />
      </div>
      <p className="hint">
        Try: <code>UPDATE public.a_panel SET color='black', updated_at=now() WHERE id=1;</code>
      </p>
    </div>
  )
}
