import { createContext, useContext, useState, useEffect } from 'react'
import { getUserData } from '../firebase/familyService'

const Ctx = createContext(null)

export function FamilyProvider({ user, children }) {
  const [familyId, setFamilyId] = useState(null)
  const [role,     setRole]     = useState(null)
  const [loading,  setLoading]  = useState(true)

  useEffect(() => {
    if (!user) { setLoading(false); return }
    getUserData(user.uid)
      .then(data => {
        setFamilyId(data?.family_id ?? null)
        setRole(data?.role ?? null)
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [user])

  return (
    <Ctx.Provider value={{ familyId, role, setFamilyId, setRole, loading }}>
      {children}
    </Ctx.Provider>
  )
}

export function useFamily() { return useContext(Ctx) }
