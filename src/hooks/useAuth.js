import { useState, useEffect } from 'react'
import { subscribeToAuth } from '../firebase/authService'

export function useAuth() {
  const [user, setUser]       = useState(undefined)  // undefined = טוען
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsub = subscribeToAuth((u) => {
      setUser(u)
      setLoading(false)
    })
    return unsub
  }, [])

  return { user, loading, isLoggedIn: !!user }
}
