import { db, FAMILY_ID } from './config'
import {
  ref, onValue, off, push, update, set, remove, serverTimestamp
} from 'firebase/database'

const eventsRef = () => ref(db, `families/${FAMILY_ID}/events`)
const eventRef  = (id) => ref(db, `families/${FAMILY_ID}/events/${id}`)

// ─── Real-time listener ───────────────────────────────────────────────────
export function subscribeToEvents(callback) {
  const r = eventsRef()
  onValue(r, (snap) => {
    const raw = snap.val() || {}
    const events = Object.entries(raw)
      .map(([id, v]) => ({ ...v, id }))
      .filter(e => !e.is_deleted)
    callback(events)
  })
  return () => off(r)
}

// ─── Create ───────────────────────────────────────────────────────────────
export async function createEvent(data, userId) {
  const newRef  = push(eventsRef())
  const id      = newRef.key
  const now     = Date.now()
  const payload = {
    id,
    title:       data.title,
    description: data.description || '',
    category:    data.category,
    location:    data.location || '',
    original_time: {
      start: data.startTs,
      end:   data.endTs,
      date:  data.date,
    },
    current_time: {
      start: data.startTs,
      end:   data.endTs,
      date:  data.date,
    },
    status:      'ON_TIME',
    status_note: '',
    recurrence: {
      is_recurring:   data.isRecurring || false,
      frequency:      data.recurrenceFreq || '',
      days_of_week:   data.recurrenceDays || [],
      end_date:       data.recurrenceEndDate || '',
    },
    attendees:    data.attendees || [],
    created_by:   userId,
    updated_by:   userId,
    created_at:   now,
    updated_at:   now,
    notification: { before_minutes: 30, enabled: true },
    color_override: data.colorOverride || null,
    is_deleted:   false,
  }
  await set(newRef, payload)
  return id
}

// ─── Update (full) ────────────────────────────────────────────────────────
export async function updateEvent(id, data, userId) {
  const now = Date.now()
  await update(eventRef(id), { ...data, updated_by: userId, updated_at: now })
}

// ─── Hot Update: status + time only ──────────────────────────────────────
export async function hotUpdateEvent(id, status, newStartTs, newEndTs, note, userId) {
  const now = Date.now()
  await update(eventRef(id), {
    status,
    status_note:  note,
    updated_by:   userId,
    updated_at:   now,
    'current_time/start': newStartTs,
    'current_time/end':   newEndTs,
  })
  await pushNotification({
    type:    `EVENT_${status}`,
    ref_id:  id,
    message: buildMessage(status, note),
    is_urgent: status === 'CANCELED' || status === 'MOVED',
  }, userId)
}

// ─── Soft Delete ──────────────────────────────────────────────────────────
export async function deleteEvent(id, userId) {
  await update(eventRef(id), { is_deleted: true, updated_by: userId, updated_at: Date.now() })
}

// ─── Notifications ───────────────────────────────────────────────────────
export async function pushNotification(data, userId) {
  const notifRef = push(ref(db, `families/${FAMILY_ID}/notifications`))
  await set(notifRef, {
    id:         notifRef.key,
    ...data,
    created_by: userId,
    created_at: Date.now(),
    read_by:    { [userId]: Date.now() },
  })
}

export function subscribeToNotifications(callback) {
  const r = ref(db, `families/${FAMILY_ID}/notifications`)
  onValue(r, (snap) => {
    const raw = snap.val() || {}
    const list = Object.values(raw).sort((a, b) => b.created_at - a.created_at)
    callback(list)
  })
  return () => off(r)
}

export async function markNotificationRead(notifId, userId) {
  await update(
    ref(db, `families/${FAMILY_ID}/notifications/${notifId}/read_by`),
    { [userId]: Date.now() }
  )
}

function buildMessage(status, note) {
  const map = { MOVED: 'הוזז', CANCELED: 'בוטל', POSTPONED: 'נדחה', RESCHEDULED: 'נקבע מחדש' }
  return `האירוע ${map[status] || 'עודכן'}${note ? ' — ' + note : ''}`
}
