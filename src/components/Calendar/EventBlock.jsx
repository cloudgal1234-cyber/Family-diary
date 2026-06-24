import { getCategoryColor, getStatusLabel, getStatusColor } from '../../utils/categoryConfig'
import { formatTime } from '../../utils/dateUtils'

const CELL_H = 60   // must match CSS --cell-h

export function eventStyle(event) {
  const start   = event.current_time?.start || 0
  const end     = event.current_time?.end   || start + 3600000
  const midnight = new Date(start)
  midnight.setHours(0,0,0,0)
  const top    = ((start - midnight.getTime()) / 3600000) * CELL_H
  const height = Math.max(((end - start) / 3600000) * CELL_H - 2, 20)
  return { top, height }
}

export default function EventBlock({ event, onClick, compact = true }) {
  const color    = event.color_override || getCategoryColor(event.category)
  const { top, height } = eventStyle(event)
  const isMoved  = event.status !== 'ON_TIME'
  const bgAlpha  = compact ? 'E6' : 'F0'

  return (
    <div
      className="event-block"
      style={{ top, height, background: `${color}${bgAlpha}` }}
      onClick={() => onClick?.(event)}
    >
      <div className="event-stripe" style={{ background: color }} />
      <div className="event-content">
        <div className="event-title">{event.title}</div>
        {height > 32 && (
          <div className="event-time">
            {formatTime(event.current_time?.start)} – {formatTime(event.current_time?.end)}
          </div>
        )}
      </div>
      {isMoved && (
        <div
          className="status-badge"
          style={{ background: getStatusColor(event.status) }}
        >
          {getStatusLabel(event.status)}
        </div>
      )}
    </div>
  )
}
