import React from 'react'

export function PanelCard({ label, color }: { label: string; color: string }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        style={{
          width: 180,
          height: 180,
          borderRadius: 16,
          boxShadow: '0 8px 24px rgba(0,0,0,.35)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontWeight: 700,
          fontSize: 18,
          color: '#111',
          background: color || 'gray',
        }}
      >
        {(color || 'gray').toUpperCase()}
      </div>
      <div style={{ marginTop: 8, color: '#888', fontSize: 14 }}>{label}</div>
    </div>
  )
}
