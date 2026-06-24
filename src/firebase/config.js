import { initializeApp } from 'firebase/app'
import { getDatabase } from 'firebase/database'
import { getAuth, GoogleAuthProvider } from 'firebase/auth'

const firebaseConfig = {
  apiKey:            import.meta.env.VITE_FIREBASE_API_KEY            || 'AIzaSyAgB_RyXiXp2Kl67peHsJm0LHG_jEguiwg',
  authDomain:        import.meta.env.VITE_FIREBASE_AUTH_DOMAIN        || 'omer-app-a565b.firebaseapp.com',
  databaseURL:       import.meta.env.VITE_FIREBASE_DATABASE_URL       || 'https://omer-app-a565b-default-rtdb.firebaseio.com',
  projectId:         import.meta.env.VITE_FIREBASE_PROJECT_ID         || 'omer-app-a565b',
  storageBucket:     import.meta.env.VITE_FIREBASE_STORAGE_BUCKET     || 'omer-app-a565b.firebasestorage.app',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || '623872250827',
  appId:             import.meta.env.VITE_FIREBASE_APP_ID             || '1:623872250827:web:da86b3d134d5768e77dc4e',
}

export const app         = initializeApp(firebaseConfig)
export const db          = getDatabase(app)
export const auth        = getAuth(app)
export const googleProvider = new GoogleAuthProvider()
export const FAMILY_ID   = import.meta.env.VITE_FAMILY_ID || 'family_demo'
