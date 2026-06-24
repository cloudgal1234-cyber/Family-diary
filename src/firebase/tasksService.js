import { db } from './config'
import { ref, onValue, off, push, update, set } from 'firebase/database'

const tasksRef = (fid)     => ref(db, `families/${fid}/tasks`)
const taskRef  = (fid, id) => ref(db, `families/${fid}/tasks/${id}`)

export function subscribeToTasks(familyId, callback) {
  const r = tasksRef(familyId)
  onValue(r, (snap) => {
    const raw   = snap.val() || {}
    const tasks = Object.entries(raw)
      .map(([id, v]) => ({ ...v, id }))
      .filter(t => !t.is_deleted)
    callback(tasks)
  })
  return () => off(r)
}

export async function createTask(familyId, data, userId) {
  const newRef = push(tasksRef(familyId))
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
    family_id:   familyId,
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

export async function toggleTaskDone(familyId, id, isDone, userId) {
  const now = Date.now()
  await update(taskRef(familyId, id), {
    status:       isDone ? 'DONE' : 'PENDING',
    completed_at: isDone ? now : null,
    updated_by:   userId,
    updated_at:   now,
  })
}

export async function updateTask(familyId, id, data, userId) {
  await update(taskRef(familyId, id), { ...data, updated_by: userId, updated_at: Date.now() })
}

export async function deleteTask(familyId, id, userId) {
  await update(taskRef(familyId, id), { is_deleted: true, updated_by: userId, updated_at: Date.now() })
}
