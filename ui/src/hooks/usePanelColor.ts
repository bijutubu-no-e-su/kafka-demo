import { useEffect, useRef, useState } from 'react'
import { fetchPanelColor, PanelName } from '../api'

export function usePanelColor(name: PanelName, intervalMs = 1000) {
  const [color, setColor] = useState<string>('gray')
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    let mounted = true
    const tick = async () => {
      try {
        const c = await fetchPanelColor(name)
        if (mounted) setColor(c)
      } catch {}
    }
    tick()
    timerRef.current = window.setInterval(tick, intervalMs)
    return () => {
      mounted = false
      if (timerRef.current) window.clearInterval(timerRef.current)
    }
  }, [name, intervalMs])

  return color
}
