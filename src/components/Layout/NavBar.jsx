export default function NavBar({ activeTab, onTabChange, unreadCount }) {
  const tabs = [
    { id: 'week',    icon: '📅', label: 'שבוע' },
    { id: 'day',     icon: '🗓️', label: 'יום' },
    { id: 'tasks',   icon: '📚', label: 'משימות' },
    { id: 'stats',   icon: '📊', label: 'סטטיסטיקה' },
  ]
  return (
    <nav className="bottom-nav">
      {tabs.map(t => (
        <button
          key={t.id}
          className={`nav-tab ${activeTab === t.id ? 'active' : ''}`}
          onClick={() => onTabChange(t.id)}
        >
          <span className="tab-icon" style={{ position: 'relative' }}>
            {t.icon}
            {t.id === 'stats' && unreadCount > 0 && (
              <span className="notif-badge">{unreadCount > 9 ? '9+' : unreadCount}</span>
            )}
          </span>
          {t.label}
        </button>
      ))}
    </nav>
  )
}
