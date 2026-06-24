import { db } from './config'
import { ref, onValue, off, push, update, set } from 'firebase/database'

const eventsRef = (fid)      => ref(db, `families/${fid}/events`)
const eventRef  = (fid, id)  => ref(db, `families/${fid}/events/${id}`)

export function subscribeToEvents(familyId, callback) {
  const r = eventsRef(familyId)
  onValue(r, (snap) => {
    const raw = snap.val() || {}
    const events = Object.entries(raw)
      .map(([id, v]) => ({ ...v, id }))
      .filter(e => !e.is_deleted)
    callback(events)
  })
  return () => off(r)
}

export async function createEvent(familyId, data, userId) {
  const newRef = push(eventsRef(familyId))
  const id     = newRef.key
  const now    = Date.now()
  await set(newRef, {
    id,
    title:       data.title,
    description: data.description || '',
    category:    data.category,
    location:    data.location || '',
    original_time: { start: data.startTs, end: data.endTs, date: data.date },
    current_time:  { start: data.startTs, end: data.endTs, date: data.date },
    status:      'ON_TIME',
    status_note: '',
    recurrence: {
      is_recurring: data.isRecurring || false,
      frequency:    data.recurrenceFreq || '',
      days_of_week: data.recurrenceDays || [],
      end_date:     data.recurrenceEndDate || '',
    },
    attendees:      data.attendees || [],
    created_by:     userId,
    updated_by:     userId,
    created_at:     now,
    updated_at:     now,
    notification:   { before_minutes: 30, enabled: true },
    color_override: data.colorOverride || null,
    is_deleted:     false,
  })
  return id
}

export async function updateEvent(familyId, id, data, userId) {
  await update(eventRef(familyId, id), { ...data, updated_by: userId, updated_at: Date.now() })
}

export async function hotUpdateEvent(familyId, id, status, newStartTs, newEndTs, note, userId) {
  const now = Date.now()
  await update(eventRef(familyId, id), {
    status,
    status_note:          note,
    updated_by:           userId,
    updated_at:           now,
    'current_time/start': newStartTs,
    'current_time/end':   newEndTs,
  })
  await pushNotification(familyId, {
    type:      `EVENT_${status}`,
    ref_id:    id,
    message:   buildMessage(status, note),
    is_urgent: status === 'CANCELED' || status === 'MOVED',
  }, userId)
}

export async function deleteEvent(familyId, id, userId) {
  await update(eventRef(familyId, id), { is_deleted: true, updated_by: userId, updated_at: Date.now() })
}

export async function pushNotification(familyId, data, userId) {
  const notifRef = push(ref(db, `families/${familyId}/notifications`))
  await set(notifRef, {
    id: notifRef.key,
    ...data,
    created_by: userId,
    created_at: Date.now(),
    read_by:    { [userId]: Date.now() },
  })
}

export function subscribeToNotifications(familyId, callback) {
  const r = ref(db, `families/${familyId}/notifications`)
  onValue(r, (snap) => {
    const raw  = snap.val() || {}
    const list = Object.values(raw).sort((a, b) => b.created_at - a.created_at)
    callback(list)
  })
  return () => off(r)
}

export async function markNotificationRead(familyId, notifId, userId) {
  await update(
    ref(db, `families/${familyId}/notifications/${notifId}/read_by`),
    { [userId]: Date.now() }
  )
}

function buildMessage(status, note) {
  const map = { MOVED: 'הוזז', CANCELED: 'בוטל', POSTPONED: 'נדחה', RESCHEDULED: 'נקבע מחדש' }
  return `האירוע ${map[status] || 'עודכן'}${note ? ' — ' + note : ''}`
}
