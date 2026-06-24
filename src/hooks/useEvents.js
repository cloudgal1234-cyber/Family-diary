import { useState, useEffect } from 'react'
import { subscribeToEvents } from '../firebase/eventsService'
import { tsToDateStr } from '../utils/dateUtils'

export function useEvents() {
  const [events, setEvents]   = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = subscribeToEvents((evts) => {
      setEvents(evts)
      setLoading(false)
    })
    return unsub
  }, [])

  function getEventsForDate(dateStr) {
    return events
      .filter(e => e.current_time?.date === dateStr)
      .sort((a, b) => (a.current_time?.start || 0) - (b.current_time?.start || 0))
  }

  function getEventsForWeek(weekStartTs) {
    const days = {}
    for (let i = 0; i < 7; i++) {
      const ts  = weekStartTs + i * 86400000
      const key = tsToDateStr(ts)
      days[key]  = []
    }
    events.forEach(e => {
      const d = e.current_time?.date
      if (d && days[d] !== undefined) days[d].push(e)
    })
    Object.values(days).forEach(arr =>
      arr.sort((a, b) => (a.current_time?.start || 0) - (b.current_time?.start || 0))
    )
    return days
  }

  function getChangedEvents() {
    return events.filter(e =>
      e.status !== 'ON_TIME' || e.current_time?.start !== e.original_time?.start
    )
  }

  return { events, loading, getEventsForDate, getEventsForWeek, getChangedEvents }
}
