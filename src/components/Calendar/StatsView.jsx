import { useMemo } from 'react'
import { useEvents } from '../../hooks/useEvents'
import { useTasks } from '../../hooks/useTasks'
import { getCurrentWeekStart, tsToDateStr } from '../../utils/dateUtils'
import { getCategoryColor, getCategoryLabel, getStatusColor } from '../../utils/categoryConfig'

export default function StatsView() {
  const { events }            = useEvents()
  const { tasks, isOverdue }  = useTasks()

  const weekStart = getCurrentWeekStart()
  const weekEnd   = weekStart + 7 * 86400000

  const stats = useMemo(() => {
    const weekEvents = events.filter(e => {
      const s = e.current_time?.start || 0
      return s >= weekStart && s < weekEnd
    })

    const total    = weekEvents.length
    const moved    = weekEvents.filter(e => e.status === 'MOVED' || e.status === 'RESCHEDULED').length
    const canceled = weekEvents.filter(e => e.status === 'CANCELED').length
    const onTime   = total - moved - canceled

    const catCount = {}
    weekEvents.forEach(e => { catCount[e.category] = (catCount[e.category] || 0) + 1 })
    const busyCat  = Object.entries(catCount).sort((a,b) => b[1]-a[1])[0]?.[0] || ''

    const totalTasks   = tasks.length
    const doneTasks    = tasks.filter(t => t.status === 'DONE').length
    const overdueTasks = tasks.filter(t => isOverdue(t)).length
    const urgentTasks  = tasks.filter(t => t.priority === 'URGENT' && t.status !== 'DONE').length
    const pct          = totalTasks ? Math.round(doneTasks * 100 / totalTasks) : 0
    const changeRate   = total ? Math.round((moved + canceled) * 100 / total) : 0

    const insights = []
    if (total === 0)          insights.push({ icon:'😴', title:'שבוע שקט', body:'אין אירועים השבוע', type:'INFO' })
    else if (changeRate > 50) insights.push({ icon:'⚠️', title:'שבוע עמוס בשינויים', body:`${changeRate}% מהאירועים השתנו`, type:'WARNING' })
    else if (changeRate === 0) insights.push({ icon:'✅', title:'שבוע יציב!', body:'כל האירועים רצו כמתוכנן', type:'SUCCESS' })
    else                      insights.push({ icon:'📊', title:'רמת שינויים נמוכה', body:`רק ${changeRate}% השתנו`, type:'INFO' })

    if (pct === 100 && totalTasks > 0) insights.push({ icon:'🏆', title:'כל המשימות הושלמו!', body:'עבודה מצוינת 🎉', type:'SUCCESS' })
    else if (pct >= 75)                insights.push({ icon:'📚', title:'כמעט שם!', body:`${pct}% מהמשימות הושלמו`, type:'INFO' })
    if (overdueTasks > 0)              insights.push({ icon:'🔴', title:`${overdueTasks} משימות פגו תוקף`, body:'יש לטפל בהן בהקדם', type:'WARNING' })
    if (urgentTasks > 0)               insights.push({ icon:'🔥', title:`${urgentTasks} משימות דחופות`, body:'ממתינות לטיפול', type:'URGENT' })
    if (busyCat)                       insights.push({ icon:'📅', title:`קטגוריה עמוסה: ${getCategoryLabel(busyCat)}`, body:`${catCount[busyCat]} אירועים השבוע`, type:'INFO' })

    return { total, moved, canceled, onTime, changeRate, totalTasks, doneTasks, overdueTasks, urgentTasks, pct, insights, catCount, busyCat }
  }, [events, tasks, weekStart])

  return (
    <div className="stats-view">
      <h2 style={{ fontSize: '1rem', fontWeight: 700, color: '#1A237E', marginBottom: 12 }}>📊 הסטטיסטיקה שלי — השבוע</h2>

      {/* Stat cards */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-num">{stats.total}</div>
          <div className="stat-label">אירועים השבוע</div>
        </div>
        <div className="stat-card">
          <div className="stat-num" style={{ color: stats.moved > 0 ? '#F39C12' : '#2ECC71' }}>{stats.moved}</div>
          <div className="stat-label">אירועים שהוזזו</div>
        </div>
        <div className="stat-card">
          <div className="stat-num">{stats.pct}%</div>
          <div className="stat-label">משימות הושלמו</div>
        </div>
        <div className="stat-card">
          <div className="stat-num" style={{ color: stats.overdueTasks > 0 ? '#E53935' : '#2ECC71' }}>
            {stats.overdueTasks}
          </div>
          <div className="stat-label">משימות באיחור</div>
        </div>
      </div>

      {/* Progress bar */}
      {stats.totalTasks > 0 && (
        <div style={{ background: '#fff', borderRadius: 14, padding: 16, marginBottom: 12, boxShadow: '0 1px 6px rgba(0,0,0,.08)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8, fontSize: '.82rem' }}>
            <span style={{ fontWeight: 600 }}>התקדמות שיעורי בית</span>
            <span style={{ color: '#9E9E9E' }}>{stats.doneTasks}/{stats.totalTasks}</span>
          </div>
          <div style={{ background: '#EEE', borderRadius: 6, height: 8, overflow: 'hidden' }}>
            <div style={{ background: '#2ECC71', width: `${stats.pct}%`, height: '100%', borderRadius: 6, transition: 'width .5s' }} />
          </div>
        </div>
      )}

      {/* Category breakdown */}
      {Object.keys(stats.catCount).length > 0 && (
        <div style={{ background: '#fff', borderRadius: 14, padding: 16, marginBottom: 12, boxShadow: '0 1px 6px rgba(0,0,0,.08)' }}>
          <div style={{ fontWeight: 700, fontSize: '.88rem', marginBottom: 10 }}>פירוט לפי קטגוריה</div>
          {Object.entries(stats.catCount).sort((a,b) => b[1]-a[1]).map(([cat, count]) => (
            <div key={cat} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
              <div style={{ flex: 1, fontSize: '.82rem' }}>{getCategoryLabel(cat)}</div>
              <div style={{ background: '#EEE', flex: 2, borderRadius: 4, height: 8 }}>
                <div style={{ background: getCategoryColor(cat), width: `${(count / stats.total) * 100}%`, height: '100%', borderRadius: 4 }} />
              </div>
              <div style={{ fontSize: '.78rem', color: '#9E9E9E', width: 20, textAlign: 'left' }}>{count}</div>
            </div>
          ))}
        </div>
      )}

      {/* Insight cards */}
      <h3 style={{ fontSize: '.88rem', fontWeight: 700, color: '#1A237E', margin: '16px 0 8px' }}>💡 תובנות</h3>
      {stats.insights.map((ins, i) => (
        <div key={i} className="insight-card">
          <div className="insight-icon">{ins.icon}</div>
          <div>
            <div className="insight-title">{ins.title}</div>
            {ins.body && <div className="insight-body">{ins.body}</div>}
          </div>
        </div>
      ))}
    </div>
  )
}
