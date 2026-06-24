import { useState, useEffect } from 'react'
import { subscribeToTasks } from '../firebase/tasksService'
import { todayStr, tomorrowStr } from '../utils/dateUtils'

export function useTasks() {
  const [tasks, setTasks]     = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = subscribeToTasks((t) => { setTasks(t); setLoading(false) })
    return unsub
  }, [])

  function filterTasks(filter) {
    switch (filter) {
      case 'TODAY':
        return tasks.filter(t => t.due?.date === todayStr() && t.status !== 'DONE')
      case 'TOMORROW':
        return tasks.filter(t => t.due?.date === tomorrowStr() && t.status !== 'DONE')
      case 'URGENT':
        return tasks.filter(t => (t.priority === 'URGENT' || t.priority === 'HIGH') && t.status !== 'DONE')
      case 'DONE':
        return tasks.filter(t => t.status === 'DONE')
      default:
        return tasks.filter(t => t.status !== 'DONE')
    }
  }

  function sortTasks(list) {
    const w = { URGENT: 4, HIGH: 3, MEDIUM: 2, LOW: 1 }
    return [...list].sort((a, b) => {
      const pd = (w[b.priority] || 0) - (w[a.priority] || 0)
      if (pd !== 0) return pd
      return (a.due?.timestamp || 0) - (b.due?.timestamp || 0)
    })
  }

  function isOverdue(task) {
    if (task.status === 'DONE') return false
    if (!task.due?.timestamp)   return false
    return Date.now() > task.due.timestamp
  }

  return { tasks, loading, filterTasks, sortTasks, isOverdue }
}
