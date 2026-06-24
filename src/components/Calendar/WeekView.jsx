import { useRef, useEffect } from 'react'
import { getWeekDays, tsToDateStr, tsToMinutesFromMidnight } from '../../utils/dateUtils'
import EventBlock from './EventBlock'

const CELL_H   = 60
const HOURS    = Array.from({ length: 24 }, (_, i) => i)
const DAY_ABBR = ['א׳','ב׳','ג׳','ד׳','ה׳','ו׳','ש׳']

export default function WeekView({ weekStartTs, eventsByDate, onEventClick, onDayClick }) {
  const scrollRef = useRef(null)
  const days      = getWeekDays(weekStartTs)
  const todayStr  = tsToDateStr(Date.now())
  const nowMins   = tsToMinutesFromMidnight(Date.now())

  // Scroll to 7am on first render
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = 7 * CELL_H - 20
    }
  }, [weekStartTs])

  return (
    <div className="week-view">
      {/* ─── Day headers ─────────────────────────── */}
      <div className="week-header">
        <div />
        {days.map(({ ts, dateStr, dayName }) => {
          const d    = new Date(ts)
          const isT  = dateStr === todayStr
          return (
            <div key={dateStr} className="week-header-cell" onClick={() => onDayClick?.(dateStr)}>
              <div className="day-name">{DAY_ABBR[d.getDay()]}</div>
              <div className={`day-num ${isT ? 'today' : ''}`}>{d.getDate()}</div>
            </div>
          )
        })}
      </div>

      {/* ─── Scrollable grid ─────────────────────── */}
      <div className="week-scroll" ref={scrollRef}>
        <div className="week-grid" style={{ minHeight: CELL_H * 24 }}>

          {/* Hour labels */}
          <div className="time-col">
            {HOURS.map(h => (
              <div key={h} className="time-label">
                {h === 0 ? '' : `${String(h).padStart(2,'0')}:00`}
              </div>
            ))}
          </div>

          {/* Day columns */}
          {days.map(({ dateStr }) => {
            const isT   = dateStr === todayStr
            const evts  = eventsByDate[dateStr] || []
            return (
              <div key={dateStr} className={`day-col ${isT ? 'today-col' : ''}`}>
                {/* Hour + half-hour lines */}
                {HOURS.map(h => (
                  <div key={h}>
                    <div className="hour-line" style={{ top: h * CELL_H }} />
                    <div className="half-line"  style={{ top: h * CELL_H + CELL_H / 2 }} />
                  </div>
                ))}

                {/* Current-time line */}
                {isT && (
                  <div className="now-line" style={{ top: (nowMins / 60) * CELL_H }}>
                    <div className="now-dot" />
                  </div>
                )}

                {/* Events */}
                {evts.map(evt => (
                  <EventBlock key={evt.id} event={evt} onClick={onEventClick} compact />
                ))}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
