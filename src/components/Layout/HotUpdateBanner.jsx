import { useState, useEffect, useRef } from 'react'

const TYPE_CONFIG = {
  EVENT_MOVED:       { color: '#F39C12', icon: '⏰' },
  EVENT_CANCELED:    { color: '#E74C3C', icon: '❌' },
  EVENT_POSTPONED:   { color: '#9B59B6', icon: '⏩' },
  EVENT_RESCHEDULED: { color: '#3498DB', icon: '📅' },
  TASK_DUE:          { color: '#3498DB', icon: '📚' },
  NEW_EVENT:         { color: '#2ECC71', icon: '🆕' },
}

export default function HotUpdateBanner({ notification, onClose, onClick }) {
  const [show, setShow]   = useState(false)
  const timerRef = useRef(null)

  useEffect(() => {
    if (!notification) return
    setShow(true)
    clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      setShow(false)
      setTimeout(onClose, 350)
    }, 5000)
    return () => clearTimeout(timerRef.current)
  }, [notification])

  if (!notification) return null

  const cfg = TYPE_CONFIG[notification.type] || { color: '#1A237E', icon: '📅' }

  return (
    <div
      className={`banner ${show ? 'show' : ''}`}
      style={{ background: cfg.color }}
      onClick={() => { onClick?.(notification); setShow(false) }}
    >
      <span className="banner-icon">{cfg.icon}</span>
      <div className="banner-text">
        <div className="banner-title">{notification.message}</div>
        {notification.body && <div className="banner-body">{notification.body}</div>}
      </div>
      <button
        className="banner-close"
        onClick={e => { e.stopPropagation(); setShow(false); setTimeout(onClose, 350) }}
      >✕</button>
    </div>
  )
}
