import { auth, googleProvider, db, FAMILY_ID } from './config'
import {
  signInWithPopup, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, signOut, onAuthStateChanged
} from 'firebase/auth'
import { ref, set, get, update } from 'firebase/database'

export function subscribeToAuth(callback) {
  return onAuthStateChanged(auth, callback)
}

export async function signInWithGoogle() {
  const result = await signInWithPopup(auth, googleProvider)
  await ensureUserInFamily(result.user, 'CHILD')
  return result.user
}

export async function signInWithEmail(email, password) {
  const result = await signInWithEmailAndPassword(auth, email, password)
  return result.user
}

export async function registerWithEmail(email, password, name) {
  const result = await createUserWithEmailAndPassword(auth, email, password)
  await ensureUserInFamily(result.user, 'CHILD', name)
  return result.user
}

export async function signOutUser() {
  await signOut(auth)
}

async function ensureUserInFamily(user, role = 'CHILD', displayName = null) {
  const userRef = ref(db, `families/${FAMILY_ID}/users/${user.uid}`)
  const snap    = await get(userRef)
  if (!snap.exists()) {
    await set(userRef, {
      id:        user.uid,
      name:      displayName || user.displayName || user.email?.split('@')[0] || 'משתמש',
      role,
      color:     randomColor(),
      family_id: FAMILY_ID,
      last_seen: Date.now(),
    })
  } else {
    await update(userRef, { last_seen: Date.now() })
  }
}

function randomColor() {
  const palette = ['#4ECDC4','#FF6B6B','#FFE66D','#A8E6CF','#C3A6FF','#FF9A9E','#96CEB4']
  return palette[Math.floor(Math.random() * palette.length)]
}
