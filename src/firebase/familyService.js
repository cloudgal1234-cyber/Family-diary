import { db } from './config'
import { ref, get, set, update } from 'firebase/database'

function randomCode() {
  return String(Math.floor(1000 + Math.random() * 9000))
}

export async function getUserData(uid) {
  const snap = await get(ref(db, `users/${uid}`))
  return snap.val()
}

export async function createFamily(user) {
  let code
  for (let i = 0; i < 10; i++) {
    code = randomCode()
    if (!(await get(ref(db, `family_codes/${code}`))).exists()) break
  }
  const familyId = `fam_${Date.now()}`
  const now = Date.now()
  await set(ref(db, `families/${familyId}`), {
    code,
    created_by: user.uid,
    created_at: now,
    members: {
      [user.uid]: { role: 'parent', name: user.displayName || user.email, joined_at: now },
    },
  })
  await set(ref(db, `family_codes/${code}`), familyId)
  await set(ref(db, `users/${user.uid}`), {
    family_id: familyId, role: 'parent',
    name: user.displayName || user.email,
    email: user.email, uid: user.uid,
  })
  return { familyId, code }
}

export async function joinFamilyByCode(code, user) {
  const snap = await get(ref(db, `family_codes/${code}`))
  if (!snap.exists()) throw new Error('קוד לא נמצא')
  const familyId = snap.val()
  const now = Date.now()
  await update(ref(db, `families/${familyId}/members/${user.uid}`), {
    role: 'child', name: user.displayName || user.email, joined_at: now,
  })
  await set(ref(db, `users/${user.uid}`), {
    family_id: familyId, role: 'child',
    name: user.displayName || user.email,
    email: user.email, uid: user.uid,
  })
  return { familyId }
}

export async function getFamilyCode(familyId) {
  const snap = await get(ref(db, `families/${familyId}/code`))
  return snap.val()
}
