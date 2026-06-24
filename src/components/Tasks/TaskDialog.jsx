import { useState, useEffect } from 'react'
import { createTask, updateTask } from '../../firebase/tasksService'
import { PRIORITIES } from '../../utils/categoryConfig'
import { todayStr, combineDateAndTime } from '../../utils/dateUtils'

const SUBJECTS = ['מתמטיקה','עברית','אנגלית','מדע','היסטוריה','גאוגרפיה','ספרות','אמנות','ספורט','אחר']
const EMPTY = {
  title: '', subject: '', priority: 'MEDIUM',
  dueDate: '', dueTime: '18:00', description: '', notes: '',
  timeBlockEnabled: false, timeBlockTime: '15:00', timeBlockDuration: '45',
}

export default function TaskDialog({ task, userId, onClose }) {
  const isEdit = !!task
  const [form, setForm]   = useState(EMPTY)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (task) {
      setForm({
        title:            task.title || '',
        subject:          task.subject || '',
        priority:         task.priority || 'MEDIUM',
        dueDate:          task.due?.date || '',
        dueTime:          task.due?.time || '18:00',
        description:      task.description || '',
        notes:            task.notes || '',
        timeBlockEnabled: task.time_block?.enabled || false,
        timeBlockTime:    task.time_block?.start_timestamp ? tsToHHMM(task.time_block.start_timestamp) : '15:00',
        timeBlockDuration: String(task.time_block?.duration_minutes || 45),
      })
    } else {
      setForm({ ...EMPTY, dueDate: todayStr() })
    }
  }, [task])

  function set(key, val) { setForm(f => ({ ...f, [key]: val })) }

  async function handleSave() {
    if (!form.title.trim()) return alert('יש להזין כותרת למשימה')
    setSaving(true)
    try {
      const dueTs = form.dueDate && form.dueTime
        ? combineDateAndTime(form.dueDate, form.dueTime)
        : 0
      const tbStart = form.timeBlockEnabled && form.dueDate
        ? combineDateAndTime(form.dueDate, form.timeBlockTime)
        : 0

      const data = {
        title: form.title, subject: form.subject, priority: form.priority,
        dueDate: form.dueDate, dueTime: form.dueTime, dueTs,
        description: form.description, notes: form.notes,
        timeBlockEnabled: form.timeBlockEnabled,
        timeBlockStart: tbStart,
        timeBlockDuration: parseInt(form.timeBlockDuration) || 45,
      }
      if (isEdit) await updateTask(task.id, data, userId)
      else        await createTask(data, userId)
      onClose()
    } finally { setSaving(false) }
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal-sheet">
        <div className="modal-handle" />
        <div className="modal-header">
          <div className="modal-title">{isEdit ? 'עריכת משימה' : 'משימה חדשה'}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">

          <div className="field-group">
            <div className="field-label">כותרת *</div>
            <input className="text-input" value={form.title} onChange={e => set('title', e.target.value)} placeholder="למשל: שיעורי בית — חשבון עמוד 45" />
          </div>

          <div className="field-group">
            <div className="field-label">מקצוע</div>
            <div className="chip-row">
              {SUBJECTS.map(s => (
                <button key={s} className={`chip ${form.subject === s ? 'selected' : ''}`}
                  style={form.subject === s ? { background: '#1A237E', borderColor: '#1A237E' } : {}}
                  onClick={() => set('subject', form.subject === s ? '' : s)}>
                  {s}
                </button>
              ))}
            </div>
          </div>

          <div className="field-group">
            <div className="field-label">עדיפות</div>
            <div className="chip-row">
              {Object.entries(PRIORITIES).map(([key, { label, color }]) => (
                <button key={key} className={`chip ${form.priority === key ? 'selected' : ''}`}
                  style={form.priority === key ? { background: color, borderColor: color } : { borderColor: color, color }}
                  onClick={() => set('priority', key)}>
                  {label}
                </button>
              ))}
            </div>
          </div>

          <div className="time-row">
            <div className="field-group">
              <div className="field-label">תאריך הגשה</div>
              <input className="text-input" type="date" value={form.dueDate} onChange={e => set('dueDate', e.target.value)} />
            </div>
            <div className="field-group">
              <div className="field-label">שעה</div>
              <input className="text-input" type="time" value={form.dueTime} onChange={e => set('dueTime', e.target.value)} />
            </div>
          </div>

          <div className="field-group">
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', marginBottom: 10 }}>
              <input type="checkbox" checked={form.timeBlockEnabled} onChange={e => set('timeBlockEnabled', e.target.checked)} />
              <span style={{ fontSize: '.9rem', fontWeight: 600 }}>⏱ חסימת זמן לעשיית המשימה</span>
            </label>
            {form.timeBlockEnabled && (
              <div className="time-row">
                <div className="field-group">
                  <div className="field-label">שעת התחלה</div>
                  <input className="text-input" type="time" value={form.timeBlockTime} onChange={e => set('timeBlockTime', e.target.value)} />
                </div>
                <div className="field-group">
                  <div className="field-label">משך (דקות)</div>
                  <input className="text-input" type="number" min="5" max="180" value={form.timeBlockDuration} onChange={e => set('timeBlockDuration', e.target.value)} />
                </div>
              </div>
            )}
          </div>

          <div className="field-group">
            <div className="field-label">הערות</div>
            <textarea className="text-input" value={form.notes} onChange={e => set('notes', e.target.value)} placeholder="צריך מחשבון, להביא ספר..." />
          </div>

        </div>
        <div className="modal-footer">
          <button className="btn btn-secondary" onClick={onClose}>ביטול</button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            {saving ? '...' : (isEdit ? 'שמור' : 'צור משימה')}
          </button>
        </div>
      </div>
    </div>
  )
}

function tsToHHMM(ts) {
  if (!ts) return '15:00'
  const d = new Date(ts)
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}
