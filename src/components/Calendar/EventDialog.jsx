import { useState, useEffect } from 'react'
import { createEvent, updateEvent, hotUpdateEvent, deleteEvent } from '../../firebase/eventsService'
import { useFamily } from '../../contexts/FamilyContext'
import { CATEGORIES, STATUSES } from '../../utils/categoryConfig'
import { tsToDateStr, combineDateAndTime } from '../../utils/dateUtils'

const EMPTY = {
  title: '', category: 'CHUGIM', date: '', startTime: '08:00', endTime: '09:00',
  location: '', description: '', status: 'ON_TIME', statusNote: '',
  isRecurring: false, recurrenceFreq: 'WEEKLY',
}

export default function EventDialog({ event, defaultDate, userId, onClose }) {
  const { familyId } = useFamily()
  const isEdit = !!event
  const [form,   setForm]   = useState(EMPTY)
  const [saving, setSaving] = useState(false)
  const [tab,    setTab]    = useState('details')

  useEffect(() => {
    if (event) {
      setForm({
        title:          event.title || '',
        category:       event.category || 'CHUGIM',
        date:           event.current_time?.date || '',
        startTime:      tsToHHMM(event.current_time?.start),
        endTime:        tsToHHMM(event.current_time?.end),
        location:       event.location || '',
        description:    event.description || '',
        status:         event.status || 'ON_TIME',
        statusNote:     event.status_note || '',
        isRecurring:    event.recurrence?.is_recurring || false,
        recurrenceFreq: event.recurrence?.frequency || 'WEEKLY',
      })
    } else {
      setForm({ ...EMPTY, date: defaultDate || tsToDateStr(Date.now()) })
    }
  }, [event, defaultDate])

  function setField(key, val) { setForm(f => ({ ...f, [key]: val })) }

  async function handleSave() {
    if (!form.title.trim()) return alert('יש להזין שם לאירוע')
    if (!form.date)         return alert('יש לבחור תאריך')
    setSaving(true)
    try {
      const startTs = combineDateAndTime(form.date, form.startTime)
      const endTs   = combineDateAndTime(form.date, form.endTime)
      if (endTs <= startTs) return alert('שעת הסיום חייבת להיות אחרי שעת ההתחלה')

      if (isEdit) {
        if (form.status !== event.status || startTs !== event.current_time?.start) {
          await hotUpdateEvent(familyId, event.id, form.status, startTs, endTs, form.statusNote, userId)
        }
        await updateEvent(familyId, event.id, {
          title: form.title, category: form.category,
          location: form.location, description: form.description,
        }, userId)
      } else {
        await createEvent(familyId, {
          title: form.title, category: form.category,
          date: form.date, startTs, endTs,
          location: form.location, description: form.description,
          isRecurring: form.isRecurring, recurrenceFreq: form.recurrenceFreq,
        }, userId)
      }
      onClose()
    } finally { setSaving(false) }
  }

  async function handleDelete() {
    if (!confirm(`למחוק את "${event.title}"?`)) return
    await deleteEvent(familyId, event.id, userId)
    onClose()
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal-sheet">
        <div className="modal-handle" />
        <div className="modal-header">
          <div className="modal-title">{isEdit ? 'עריכת אירוע' : 'אירוע חדש'}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        {isEdit && (
          <div style={{ display: 'flex', borderBottom: '1px solid #EEE', padding: '0 20px' }}>
            {[['details','פרטים'], ['status','סטטוס 🔥']].map(([id, lbl]) => (
              <button key={id} onClick={() => setTab(id)}
                style={{ padding: '10px 16px', border: 'none', background: 'none', cursor: 'pointer',
                  fontWeight: tab === id ? 700 : 400, color: tab === id ? '#1A237E' : '#9E9E9E',
                  borderBottom: tab === id ? '2px solid #1A237E' : '2px solid transparent',
                  marginBottom: -1, fontSize: '.88rem' }}>
                {lbl}
              </button>
            ))}
          </div>
        )}

        <div className="modal-body">
          {tab === 'details' && (
            <>
              <div className="field-group">
                <div className="field-label">שם האירוע *</div>
                <input className="text-input" value={form.title} onChange={e => setField('title', e.target.value)} placeholder="למשל: חוג שחייה" />
              </div>
              <div className="field-group">
                <div className="field-label">קטגוריה</div>
                <div className="chip-row">
                  {Object.entries(CATEGORIES).map(([key, { label, color, emoji }]) => (
                    <button key={key} className={`chip ${form.category === key ? 'selected' : ''}`}
                      style={form.category === key ? { background: color, borderColor: color } : { borderColor: color, color }}
                      onClick={() => setField('category', key)}>
                      {emoji} {label}
                    </button>
                  ))}
                </div>
              </div>
              <div className="field-group">
                <div className="field-label">תאריך *</div>
                <input className="text-input" type="date" value={form.date} onChange={e => setField('date', e.target.value)} />
              </div>
              <div className="time-row">
                <div className="field-group">
                  <div className="field-label">שעת התחלה</div>
                  <input className="text-input" type="time" value={form.startTime} onChange={e => setField('startTime', e.target.value)} />
                </div>
                <div className="field-group">
                  <div className="field-label">שעת סיום</div>
                  <input className="text-input" type="time" value={form.endTime} onChange={e => setField('endTime', e.target.value)} />
                </div>
              </div>
              <div className="field-group">
                <div className="field-label">מיקום</div>
                <input className="text-input" value={form.location} onChange={e => setField('location', e.target.value)} placeholder="בריכה, כיתה, בית..." />
              </div>
              <div className="field-group">
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                  <input type="checkbox" checked={form.isRecurring} onChange={e => setField('isRecurring', e.target.checked)} />
                  <span style={{ fontSize: '.9rem' }}>אירוע חוזר (כל שבוע)</span>
                </label>
              </div>
            </>
          )}

          {tab === 'status' && (
            <>
              <div className="field-group">
                <div className="field-label">סטטוס Hot Update</div>
                <div className="chip-row">
                  {Object.entries(STATUSES).map(([key, { label, color }]) => (
                    <button key={key} className={`chip ${form.status === key ? 'selected' : ''}`}
                      style={form.status === key ? { background: color, borderColor: color } : { borderColor: color, color }}
                      onClick={() => setField('status', key)}>
                      {label}
                    </button>
                  ))}
                </div>
              </div>
              {form.status !== 'ON_TIME' && (
                <>
                  <div className="field-group">
                    <div className="field-label">שעת התחלה חדשה</div>
                    <input className="text-input" type="time" value={form.startTime} onChange={e => setField('startTime', e.target.value)} />
                  </div>
                  <div className="field-group">
                    <div className="field-label">הסבר (לבני המשפחה)</div>
                    <textarea className="text-input" value={form.statusNote} onChange={e => setField('statusNote', e.target.value)} placeholder="למשל: המאמן ביקש להזיז..." />
                  </div>
                </>
              )}
              {form.status === 'ON_TIME' && (
                <div style={{ textAlign: 'center', color: '#9E9E9E', padding: '20px 0', fontSize: '.9rem' }}>
                  ✅ האירוע מתקיים בזמן המקורי
                </div>
              )}
            </>
          )}
        </div>

        <div className="modal-footer">
          {isEdit && (
            <button className="btn btn-danger" onClick={handleDelete} style={{ flex: '0 0 auto', padding: '13px 16px' }}>🗑️</button>
          )}
          <button className="btn btn-secondary" onClick={onClose}>ביטול</button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            {saving ? '...' : (isEdit ? 'שמור שינויים' : 'צור אירוע')}
          </button>
        </div>
      </div>
    </div>
  )
}

function tsToHHMM(ts) {
  if (!ts) return '08:00'
  const d = new Date(ts)
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}
