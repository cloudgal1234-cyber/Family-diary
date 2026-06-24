import { useState, useEffect, useRef } from 'react'
import { useAuth }   from './hooks/useAuth'
import { useEvents } from './hooks/useEvents'

import NavBar          from './components/Layout/NavBar'
import HotUpdateBanner from './components/Layout/HotUpdateBanner'
import LoginScreen     from './components/Layout/LoginScreen'
import WeekView        from './components/Calendar/WeekView'
import DayView         from './components/Calendar/DayView'
import EventDialog     from './components/Calendar/EventDialog'
import StatsView       from './components/Calendar/StatsView'
import TaskList        from './components/Tasks/TaskList'
import TaskDialog      from './components/Tasks/TaskDialog'

import { subscribeToNotifications, markNotificationRead } from './firebase/eventsService'
import { signOutUser } from './firebase/authService'
import { getCurrentWeekStart, tsToDateStr } from './utils/dateUtils'

import './styles/app.css'

export default function App() {
  const { user, loading } = useAuth()

  // ── Navigation state ─────────────────────────────────────────
  const [tab,          setTab]         = useState('week')
  const [weekStart,    setWeekStart]   = useState(getCurrentWeekStart)
  const [selectedDate, setSelectedDate] = useState(tsToDateStr(Date.now()))

  // ── Dialog state ─────────────────────────────────────────────
  const [eventDialog, setEventDialog] = useState(null)  // null | { event?, date? }
  const [taskDialog,  setTaskDialog]  = useState(null)  // null | { task? }

  // ── Notifications & banner ────────────────────────────────────
  const [notifications, setNotifications] = useState([])
  const [banner,        setBanner]        = useState(null)
  const seenNotifsRef = useRef(new Set())

  // ── Events ────────────────────────────────────────────────────
  const { getEventsForDate, getEventsForWeek, getChangedEvents } = useEvents()
  const eventsByDate = getEventsForWeek(weekStart)
  const dayEvents    = getEventsForDate(selectedDate)
  const changedEvts  = getChangedEvents()

  // ── Subscribe to notifications ────────────────────────────────
  useEffect(() => {
    if (!user) return
    const unsub = subscribeToNotifications((notifs) => {
      setNotifications(notifs)
      // Show banner for new unseen notifications
      const newest = notifs.find(n => {
        const readByMe = n.read_by?.[user.uid]
        return !readByMe && !seenNotifsRef.current.has(n.id)
      })
      if (newest) {
        seenNotifsRef.current.add(newest.id)
        setBanner(newest)
      }
    })
    return unsub
  }, [user])

  const unreadCount = notifications.filter(n => !n.read_by?.[user?.uid]).length

  // ── Loading screen ─────────────────────────────────────────────
  if (loading) {
    return (
      <div className="loading-screen">
        <div className="loader" />
        <p>טוען...</p>
      </div>
    )
  }

  if (!user) return <LoginScreen />

  // ── Week navigation ────────────────────────────────────────────
  function goNextWeek() { setWeekStart(w => w + 7 * 86400000) }
  function goPrevWeek() { setWeekStart(w => w - 7 * 86400000) }
  function goThisWeek() { setWeekStart(getCurrentWeekStart()) }

  function goNextDay() {
    const ts = new Date(selectedDate).getTime() + 86400000 + 3600000  // +1h for DST safety
    setSelectedDate(tsToDateStr(ts))
  }
  function goPrevDay() {
    const ts = new Date(selectedDate).getTime() - 86400000 + 3600000
    setSelectedDate(tsToDateStr(ts))
  }

  // ── FAB action ────────────────────────────────────────────────
  function handleFAB() {
    if (tab === 'tasks') setTaskDialog({})
    else setEventDialog({ date: tab === 'day' ? selectedDate : tsToDateStr(Date.now()) })
  }

  // ── Render ────────────────────────────────────────────────────
  return (
    <div className="app-shell">
      {/* ── Global Banner ── */}
      <HotUpdateBanner
        notification={banner}
        onClose={() => setBanner(null)}
        onClick={n => { if (n?.id && user) markNotificationRead(n.id, user.uid) }}
      />

      {/* ── Header ── */}
      <header className="app-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: '1.3rem' }}>📅</span>
          <h1>יומן משפחה</h1>
        </div>
        <div className="header-actions">
          {tab === 'week' && (
            <>
              <button className="icon-btn" onClick={goPrevWeek} title="שבוע קודם">‹</button>
              <button className="icon-btn" onClick={goThisWeek} title="השבוע">●</button>
              <button className="icon-btn" onClick={goNextWeek} title="שבוע הבא">›</button>
            </>
          )}
          <button className="icon-btn" onClick={() => signOutUser()} title="יציאה" style={{ fontSize: '.9rem' }}>🚪</button>
        </div>
      </header>

      {/* ── Main content ── */}
      <main className="main-content">

        {/* Week view */}
        <div className={`view-panel ${tab === 'week' ? 'active' : ''}`}>
          <WeekView
            weekStartTs   = {weekStart}
            eventsByDate  = {eventsByDate}
            onEventClick  = {evt => setEventDialog({ event: evt })}
            onDayClick    = {date => { setSelectedDate(date); setTab('day') }}
          />
        </div>

        {/* Day view */}
        <div className={`view-panel ${tab === 'day' ? 'active' : ''}`}>
          <DayView
            dateStr      = {selectedDate}
            events       = {dayEvents}
            changedEvents = {changedEvts}
            onEventClick = {evt => setEventDialog({ event: evt })}
            onPrev       = {goPrevDay}
            onNext       = {goNextDay}
          />
        </div>

        {/* Tasks */}
        <div className={`view-panel ${tab === 'tasks' ? 'active' : ''}`}>
          <TaskList
            userId      = {user.uid}
            onEditTask  = {task => setTaskDialog({ task })}
          />
        </div>

        {/* Stats */}
        <div className={`view-panel ${tab === 'stats' ? 'active' : ''}`}>
          <StatsView />
        </div>

      </main>

      {/* ── Bottom Nav ── */}
      <NavBar activeTab={tab} onTabChange={setTab} unreadCount={unreadCount} />

      {/* ── FAB ── */}
      {(tab === 'week' || tab === 'day' || tab === 'tasks') && (
        <button className="fab" onClick={handleFAB} aria-label="הוסף">＋</button>
      )}

      {/* ── Dialogs ── */}
      {eventDialog && (
        <EventDialog
          event       = {eventDialog.event}
          defaultDate = {eventDialog.date}
          userId      = {user.uid}
          onClose     = {() => setEventDialog(null)}
        />
      )}
      {taskDialog && (
        <TaskDialog
          task   = {taskDialog.task}
          userId = {user.uid}
          onClose = {() => setTaskDialog(null)}
        />
      )}
    </div>
  )
}
