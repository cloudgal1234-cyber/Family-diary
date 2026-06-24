import { db, FAMILY_ID } from './config'
import { ref, onValue, off, push, update, set } from 'firebase/database'

const tasksRef = () => ref(db, `families/${FAMILY_ID}/tasks`)
const taskRef  = (id) => ref(db, `families/${FAMILY_ID}/tasks/${id}`)

export function subscribeToTasks(callback) {
  const r = tasksRef()
  onValue(r, (snap) => {
    const raw = snap.val() || {}
    const tasks = Object.entries(raw)
      .map(([id, v]) => ({ ...v, id }))
      .filter(t => !t.is_deleted)
    callback(tasks)
  })
  return () => off(r)
}

export async function createTask(data, userId) {
  const newRef = push(tasksRef())
  const id     = newRef.key
  const now    = Date.now()
  await set(newRef, {
    id,
    title:       data.title,
    subject:     data.subject || '',
    description: data.description || '',
    notes:       data.notes || '',
    priority:    data.priority || 'MEDIUM',
    status:      'PENDING',
    family_id:   FAMILY_ID,
    due: {
      date:      data.dueDate || '',
      time:      data.dueTime || '',
      timestamp: data.dueTs || 0,
    },
    time_block: {
      enabled:          data.timeBlockEnabled || false,
      start_timestamp:  data.timeBlockStart || 0,
      duration_minutes: data.timeBlockDuration || 0,
    },
    assigned_to:  data.assignedTo || userId,
    created_by:   userId,
    updated_by:   userId,
    created_at:   now,
    updated_at:   now,
    completed_at: null,
    is_deleted:   false,
  })
  return id
}

export async function toggleTaskDone(id, isDone, userId) {
  const now = Date.now()
  await update(taskRef(id), {
    status:       isDone ? 'DONE' : 'PENDING',
    completed_at: isDone ? now : null,
    updated_by:   userId,
    updated_at:   now,
  })
}

export async function updateTask(id, data, userId) {
  await update(taskRef(id), { ...data, updated_by: userId, updated_at: Date.now() })
}

export async function deleteTask(id, userId) {
  await update(taskRef(id), { is_deleted: true, updated_by: userId, updated_at: Date.now() })
}
