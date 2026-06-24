import { useState, useEffect, useRef } from 'react'
import { useAuth }   from './hooks/useAuth'
import { useEvents } from './hooks/useEvents'

import NavBar          from './components/Layout/NavBar'
import HotUpdateBanner from './components/Layout/HotUpdateBanner'
import LoginScreen     from './components/Layout/LoginScreen'
import RoleScreen      from './components/Layout/RoleScreen'
import WeekView        from './components/Calendar/WeekView'
import DayView         from './components/Calendar/DayView'
import EventDialog     from './components/Calendar/EventDialog'
import StatsView       from './components/Calendar/StatsView'
import TaskList        from './components/Tasks/TaskList'
import TaskDialog      from './components/Tasks/TaskDialog'

import { FamilyProvider, useFamily } from './contexts/FamilyContext'
import { subscribeToNotifications, markNotificationRead } from './firebase/eventsService'
import { getFamilyCode } from './firebase/familyService'
import { signOutUser } from './firebase/authService'
import { getCurrentWeekStart, tsToDateStr } from './utils/dateUtils'

import './styles/app.css'

// ── Root: handles auth then wraps with FamilyProvider ────────────
export default function App() {
  const { user, loading } = useAuth()

  if (loading) return <Spinner />
  if (!user)   return <LoginScreen />

  return (
    <FamilyProvider user={user}>
      <AppShell user={user} />
    </FamilyProvider>
  )
}

function Spinner() {
  return (
    <div className="loading-screen">
      <div className="loader" />
      <p>טוען...</p>
    </div>
  )
}

// ── Main shell: needs FamilyProvider already mounted ─────────────
function AppShell({ user }) {
  const { familyId, role, setFamilyId, setRole, loading: familyLoading } = useFamily()

  // ── Navigation state ─────────────────────────────────────────
  const [tab,          setTab]          = useState('week')
  const [weekStart,    setWeekStart]    = useState(getCurrentWeekStart)
  const [selectedDate, setSelectedDate] = useState(tsToDateStr(Date.now()))

  // ── Dialog state ─────────────────────────────────────────────
  const [eventDialog, setEventDialog] = useState(null)
  const [taskDialog,  setTaskDialog]  = useState(null)
  const [codeDialog,  setCodeDialog]  = useState(false)
  const [familyCode,  setFamilyCode]  = useState('')

  // ── Notifications & banner ────────────────────────────────────
  const [notifications, setNotifications] = useState([])
  const [banner,        setBanner]        = useState(null)
  const seenNotifsRef = useRef(new Set())

  // ── Events (reads from FamilyContext internally) ──────────────
  const { getEventsForDate, getEventsForWeek, getChangedEvents } = useEvents()
  const eventsByDate = getEventsForWeek(weekStart)
  const dayEvents    = getEventsForDate(selectedDate)
  const changedEvts  = getChangedEvents()

  // ── Subscribe to notifications ────────────────────────────────
  useEffect(() => {
    if (!user || !familyId) return
    const unsub = subscribeToNotifications(familyId, (notifs) => {
      setNotifications(notifs)
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
  }, [user, familyId])

  // ── Loading / role selection ──────────────────────────────────
  if (familyLoading) return <Spinner />
  if (!familyId) {
    return (
      <RoleScreen
        user={user}
        onFamilySet={(fid, r) => { setFamilyId(fid); setRole(r) }}
      />
    )
  }

  const unreadCount = notifications.filter(n => !n.read_by?.[user?.uid]).length

  // ── Week navigation ───────────────────────────────────────────
  function goNextWeek() { setWeekStart(w => w + 7 * 86400000) }
  function goPrevWeek() { setWeekStart(w => w - 7 * 86400000) }
  function goThisWeek() { setWeekStart(getCurrentWeekStart()) }

  function goNextDay() {
    setSelectedDate(tsToDateStr(new Date(selectedDate).getTime() + 86400000 + 3600000))
  }
  function goPrevDay() {
    setSelectedDate(tsToDateStr(new Date(selectedDate).getTime() - 86400000 + 3600000))
  }

  // ── FAB ───────────────────────────────────────────────────────
  function handleFAB() {
    if (tab === 'tasks') setTaskDialog({})
    else setEventDialog({ date: tab === 'day' ? selectedDate : tsToDateStr(Date.now()) })
  }

  // ── Show family code dialog (parents only) ────────────────────
  async function handleShowCode() {
    const code = await getFamilyCode(familyId)
    setFamilyCode(code)
    setCodeDialog(true)
  }

  // ── Render ────────────────────────────────────────────────────
  return (
    <div className="app-shell">

      {/* ── Global Banner ── */}
      <HotUpdateBanner
        notification={banner}
        onClose={() => setBanner(null)}
        onClick={n => { if (n?.id && user) markNotificationRead(familyId, n.id, user.uid) }}
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
          {role === 'parent' && (
            <button className="icon-btn" onClick={handleShowCode} title="הוסף ילד" style={{ fontSize: '1rem' }}>
              👶+
            </button>
          )}
          <button className="icon-btn" onClick={() => signOutUser()} title="יציאה" style={{ fontSize: '.9rem' }}>🚪</button>
        </div>
      </header>

      {/* ── Main content ── */}
      <main className="main-content">

        <div className={`view-panel ${tab === 'week' ? 'active' : ''}`}>
          <WeekView
            weekStartTs   = {weekStart}
            eventsByDate  = {eventsByDate}
            onEventClick  = {evt => setEventDialog({ event: evt })}
            onDayClick    = {date => { setSelectedDate(date); setTab('day') }}
          />
        </div>

        <div className={`view-panel ${tab === 'day' ? 'active' : ''}`}>
          <DayView
            dateStr       = {selectedDate}
            events        = {dayEvents}
            changedEvents = {changedEvts}
            onEventClick  = {evt => setEventDialog({ event: evt })}
            onPrev        = {goPrevDay}
            onNext        = {goNextDay}
          />
        </div>

        <div className={`view-panel ${tab === 'tasks' ? 'active' : ''}`}>
          <TaskList userId={user.uid} onEditTask={task => setTaskDialog({ task })} />
        </div>

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

      {/* ── Event Dialog ── */}
      {eventDialog && (
        <EventDialog
          event       = {eventDialog.event}
          defaultDate = {eventDialog.date}
          userId      = {user.uid}
          onClose     = {() => setEventDialog(null)}
        />
      )}

      {/* ── Task Dialog ── */}
      {taskDialog && (
        <TaskDialog
          task    = {taskDialog.task}
          userId  = {user.uid}
          onClose = {() => setTaskDialog(null)}
        />
      )}

      {/* ── Add Child Dialog (parents only) ── */}
      {codeDialog && (
        <div className="modal-overlay" onClick={() => setCodeDialog(false)}>
          <div className="modal-sheet" onClick={e => e.stopPropagation()} style={{ paddingBottom: 28 }}>
            <div className="modal-handle" />
            <div className="modal-header">
              <div className="modal-title">👶 הוסף ילד למשפחה</div>
              <button className="modal-close" onClick={() => setCodeDialog(false)}>✕</button>
            </div>
            <div className="modal-body" style={{ textAlign: 'center' }}>
              <p style={{ color: '#616161', marginBottom: 16 }}>שתף קוד זה עם הילד:</p>
              <div style={{
                fontSize: '3.5rem', fontWeight: 900, letterSpacing: 16,
                color: '#1A237E', background: '#E8EAF6',
                borderRadius: 16, padding: '20px 0', marginBottom: 16,
              }}>
                {familyCode}
              </div>
              <p style={{ color: '#9E9E9E', fontSize: '.82rem', lineHeight: 1.6 }}>
                הילד יכנס לאפליקציה ← יבחר <strong>אני ילד</strong> ← יכניס קוד זה
              </p>
            </div>
          </div>
        </div>
      )}

    </div>
  )
}
