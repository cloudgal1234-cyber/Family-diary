import { useState } from 'react'
import { createFamily, joinFamilyByCode } from '../../firebase/familyService'

export default function RoleScreen({ user, onFamilySet }) {
  const [step,       setStep]       = useState('choose')
  const [code,       setCode]       = useState('')
  const [myCode,     setMyCode]     = useState('')
  const [pendingFid, setPendingFid] = useState(null)
  const [error,      setError]      = useState('')
  const [loading,    setLoading]    = useState(false)

  const firstName = user.displayName?.split(' ')[0] || ''

  async function handleParent() {
    setLoading(true); setError('')
    try {
      const { familyId, code: c } = await createFamily(user)
      setMyCode(c)
      setPendingFid(familyId)
      setStep('parent-code')
    } catch { setError('שגיאה ביצירת המשפחה, נסה שוב') }
    finally  { setLoading(false) }
  }

  async function handleChildJoin() {
    if (code.length !== 4) return setError('הקוד חייב להיות 4 ספרות')
    setLoading(true); setError('')
    try {
      const { familyId } = await joinFamilyByCode(code, user)
      onFamilySet(familyId, 'child')
    } catch { setError('קוד שגוי — בדוק שוב עם ההורה') }
    finally  { setLoading(false) }
  }

  return (
    <div className="login-screen">
      <div className="login-logo">👨‍👩‍👧</div>
      <h1 className="login-title">יומן משפחה</h1>
      {firstName && <p className="login-sub">ברוך הבא, {firstName}!</p>}

      <div className="login-card">

        {step === 'choose' && (
          <>
            <h2 style={{ textAlign: 'center', marginBottom: 20, color: '#1A237E' }}>מי אתה?</h2>
            <button
              className="btn btn-primary"
              style={{ marginBottom: 12, fontSize: '1rem', padding: 16 }}
              onClick={handleParent}
              disabled={loading}
            >
              {loading ? '...' : '👨‍👩 אני הורה — צור משפחה חדשה'}
            </button>
            <button
              className="btn btn-secondary"
              style={{ fontSize: '1rem', padding: 16 }}
              onClick={() => { setStep('child-code'); setError('') }}
            >
              👧 אני ילד — הצטרף למשפחה
            </button>
            {error && <div className="error-msg" style={{ marginTop: 12 }}>{error}</div>}
          </>
        )}

        {step === 'parent-code' && (
          <>
            <h2 style={{ textAlign: 'center', marginBottom: 8, color: '#1A237E' }}>✅ המשפחה נוצרה!</h2>
            <p style={{ textAlign: 'center', color: '#616161', fontSize: '.88rem', marginBottom: 8 }}>
              קוד המשפחה שלך:
            </p>
            <div style={{
              fontSize: '3.5rem', fontWeight: 900, textAlign: 'center',
              letterSpacing: 16, color: '#1A237E',
              background: '#E8EAF6', borderRadius: 16, padding: '20px 0', marginBottom: 12,
            }}>
              {myCode}
            </div>
            <p style={{ textAlign: 'center', color: '#9E9E9E', fontSize: '.8rem', marginBottom: 20 }}>
              שתף קוד זה עם ילדיך כדי שיצטרפו
            </p>
            <button
              className="btn btn-primary"
              style={{ fontSize: '1rem', padding: 16 }}
              onClick={() => onFamilySet(pendingFid, 'parent')}
            >
              בוא נתחיל ←
            </button>
          </>
        )}

        {step === 'child-code' && (
          <>
            <h2 style={{ textAlign: 'center', marginBottom: 8, color: '#1A237E' }}>הכנס קוד משפחה</h2>
            <p style={{ textAlign: 'center', color: '#9E9E9E', fontSize: '.82rem', marginBottom: 16 }}>
              בקש מההורה שלך את הקוד בן 4 הספרות
            </p>
            <input
              className="text-input"
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={4}
              value={code}
              onChange={e => { setCode(e.target.value.replace(/\D/g, '').slice(0, 4)); setError('') }}
              placeholder="1 2 3 4"
              style={{ fontSize: '2.5rem', textAlign: 'center', letterSpacing: 16, marginBottom: 8 }}
            />
            {error && <div className="error-msg" style={{ marginBottom: 8 }}>{error}</div>}
            <div style={{ display: 'flex', gap: 10, marginTop: 8 }}>
              <button
                className="btn btn-secondary"
                onClick={() => { setStep('choose'); setCode(''); setError('') }}
              >חזור</button>
              <button
                className="btn btn-primary"
                onClick={handleChildJoin}
                disabled={loading || code.length !== 4}
              >
                {loading ? '...' : 'הצטרף'}
              </button>
            </div>
          </>
        )}

      </div>
    </div>
  )
}
