import React from 'react'
import { usePanelColor } from './hooks/usePanelColor'
import { PanelCard } from './components/PanelCard'

export default function App() {
  const a = usePanelColor('a')
  const b = usePanelColor('b')
  const c = usePanelColor('c')
  const d = usePanelColor('d')

  return (
    <div
      style={{
        minHeight: '100dvh',
        display: 'grid',
        placeItems: 'center',
        background: '#111',
        color: '#eee',
        fontFamily: 'system-ui, sans-serif',
      }}
    >
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(3, 180px)',
          gap: 24,
        }}
      >
        <PanelCard label="a_panel" color={a} />
        <PanelCard label="b_panel" color={b} />
        <PanelCard label="c_panel" color={c} />
        <PanelCard label="d_panel" color={d} />
      </div>
    </div>
  )
}
