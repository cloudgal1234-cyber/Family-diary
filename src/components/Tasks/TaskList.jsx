import { useState } from 'react'
import { useTasks } from '../../hooks/useTasks'
import { useFamily } from '../../contexts/FamilyContext'
import { toggleTaskDone, deleteTask } from '../../firebase/tasksService'
import { PRIORITIES } from '../../utils/categoryConfig'
import { todayStr, tomorrowStr } from '../../utils/dateUtils'

const FILTERS = [
  { id: 'ALL',      label: 'הכל' },
  { id: 'TODAY',    label: 'היום' },
  { id: 'TOMORROW', label: 'מחר' },
  { id: 'URGENT',   label: '🔥 דחוף' },
  { id: 'DONE',     label: '✅ הושלם' },
]

export default function TaskList({ userId, onEditTask }) {
  const { familyId } = useFamily()
  const [filter, setFilter] = useState('ALL')
  const { filterTasks, sortTasks, isOverdue } = useTasks()
  const tasks = sortTasks(filterTasks(filter))

  async function handleToggle(task) {
    await toggleTaskDone(familyId, task.id, task.status !== 'DONE', userId)
  }

  async function handleDelete(taskId) {
    if (confirm('למחוק את המשימה?')) await deleteTask(familyId, taskId, userId)
  }

  function formatDue(task) {
    if (!task.due?.date) return null
    if (task.due.date === todayStr())    return `היום ${task.due.time || ''}`
    if (task.due.date === tomorrowStr()) return `מחר ${task.due.time || ''}`
    return `${task.due.date} ${task.due.time || ''}`
  }

  return (
    <div className="task-view">
      <div className="filter-bar">
        {FILTERS.map(f => (
          <button key={f.id} className={`filter-btn ${filter === f.id ? 'active' : ''}`} onClick={() => setFilter(f.id)}>
            {f.label}
          </button>
        ))}
      </div>

      <div className="task-scroll">
        {tasks.length === 0 ? (
          <div className="empty-state">
            <div className="emoji">✅</div>
            <p>אין משימות!</p>
            <p style={{ fontSize: '.82rem', marginTop: 6, color: '#9E9E9E' }}>
              {filter === 'DONE' ? 'עוד לא הושלמה אף משימה' : 'כל השיעורי בית הושלמו 🎉'}
            </p>
          </div>
        ) : (
          tasks.map(task => {
            const done      = task.status === 'DONE'
            const overdue   = isOverdue(task)
            const prioColor = PRIORITIES[task.priority]?.color || '#9E9E9E'
            const dueText   = formatDue(task)

            return (
              <div key={task.id}
                className={`task-item ${done ? 'done' : ''} ${overdue ? 'overdue' : ''}`}
                onDoubleClick={() => onEditTask?.(task)}
              >
                <div className="task-priority-bar" style={{ background: prioColor }} />
                <div className="task-checkbox-wrap">
                  <button
                    className={`task-checkbox ${done ? 'checked' : ''}`}
                    onClick={() => handleToggle(task)}
                    aria-label={done ? 'בטל השלמה' : 'סמן כהושלם'}
                  />
                </div>
                <div className="task-body">
                  <div className={`task-title ${done ? 'done' : ''}`}>{task.title}</div>
                  {task.subject && <div className="task-subject">{task.subject}</div>}
                  <div className="task-meta">
                    {dueText && (
                      <span className={`task-due ${overdue ? 'overdue' : ''}`}>
                        {overdue ? '⚠️ ' : '📅 '}{dueText}
                      </span>
                    )}
                    {task.time_block?.enabled && task.time_block.start_timestamp > 0 && (
                      <span className="task-time-block">
                        ⏱ {new Date(task.time_block.start_timestamp).toLocaleTimeString('he-IL', { hour: '2-digit', minute: '2-digit' })}
                        {' '}({task.time_block.duration_minutes} דק׳)
                      </span>
                    )}
                    {task.priority === 'URGENT' && !done && (
                      <span className="priority-tag" style={{ background: '#FFEBEE', color: '#E53935' }}>🔥 דחוף</span>
                    )}
                  </div>
                </div>
                <button
                  style={{ background: 'none', border: 'none', padding: '12px 10px', cursor: 'pointer', color: '#BDBDBD', fontSize: '1rem' }}
                  onClick={() => handleDelete(task.id)}
                  aria-label="מחק"
                >✕</button>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
