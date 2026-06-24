import { useRef, useEffect } from 'react'
import {
  formatDateHebrew, tsToDateStr, tsToMinutesFromMidnight, getMidnight
} from '../../utils/dateUtils'
import { getCategoryColor, getStatusColor, getStatusLabel } from '../../utils/categoryConfig'
import { formatTime } from '../../utils/dateUtils'

const CELL_H = 60
const HOURS  = Array.from({ length: 24 }, (_, i) => i)

export default function DayView({ dateStr, events, changedEvents, onEventClick, onPrev, onNext }) {
  const scrollRef = useRef(null)
  const ts        = new Date(dateStr).getTime()
  const isToday   = dateStr === tsToDateStr(Date.now())
  const nowMins   = tsToMinutesFromMidnight(Date.now())

  const todayChanged = changedEvents.filter(e => e.current_time?.date === dateStr)

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = 7 * CELL_H - 40
  }, [dateStr])

  return (
    <div className="day-view">
      {/* Header */}
      <div className="day-header">
        <button className="day-nav-btn" onClick={onNext}>‹</button>
        <div className="day-title">{formatDateHebrew(ts)}</div>
        <button className="day-nav-btn" onClick={onPrev}>›</button>
      </div>

      {/* Changes strip */}
      {todayChanged.length > 0 && (
        <div className="changes-strip">
          <div className="changes-strip-title">⚡ שינויים להיום:</div>
          {todayChanged.map(e => (
            <div key={e.id} className="changes-strip-item">
              • {e.title} — {getStatusLabel(e.status)}
            </div>
          ))}
        </div>
      )}

      {/* Timeline */}
      <div className="day-scroll" ref={scrollRef}>
        <div className="day-timeline" style={{ minHeight: CELL_H * 24 }}>
          {/* Hour labels */}
          <div>
            {HOURS.map(h => (
              <div key={h} className="time-label">
                {h === 0 ? '' : `${String(h).padStart(2,'0')}:00`}
              </div>
            ))}
          </div>

          {/* Events area */}
          <div style={{ position: 'relative' }}>
            {HOURS.map(h => (
              <div key={h}>
                <div className="hour-line" style={{ top: h * CELL_H }} />
                <div className="half-line" style={{ top: h * CELL_H + CELL_H / 2 }} />
              </div>
            ))}

            {isToday && (
              <div className="now-line" style={{ top: (nowMins / 60) * CELL_H }}>
                <div className="now-dot" />
              </div>
            )}

            {events.map(evt => {
              const start    = evt.current_time?.start || 0
              const end      = evt.current_time?.end   || start + 3600000
              const midnight = getMidnight(start)
              const top      = ((start - midnight) / 3600000) * CELL_H
              const height   = Math.max(((end - start) / 3600000) * CELL_H - 4, 44)
              const color    = evt.color_override || getCategoryColor(evt.category)
              const isMoved  = evt.status !== 'ON_TIME'

              return (
                <div
                  key={evt.id}
                  className="day-event-block"
                  style={{ top, height, background: `${color}F0` }}
                  onClick={() => onEventClick?.(evt)}
                >
                  <div className="day-event-left-bar" style={{ background: color }} />
                  <div className="day-event-content">
                    <div className="day-event-title">{evt.title}</div>
                    <div className="day-event-time">
                      {formatTime(start)} – {formatTime(end)}
                    </div>
                    {evt.location && (
                      <div className="day-event-location">📍 {evt.location}</div>
                    )}
                    {isMoved && evt.original_time?.start !== evt.current_time?.start && (
                      <div className="day-event-original">
                        מקורי: {formatTime(evt.original_time.start)}
                      </div>
                    )}
                  </div>
                  {isMoved && (
                    <div
                      className="day-status-badge"
                      style={{ background: getStatusColor(evt.status) }}
                    >
                      {getStatusLabel(evt.status)}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
