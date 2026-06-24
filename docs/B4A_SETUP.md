# הגדרת פרויקט B4A — Family Diary (Android)

## שלב 1: הורדת B4A

1. לך ל-https://www.b4x.com/b4a.html
2. הורד **B4A** (גרסה 12.x ומעלה)
3. הורד גם **Java JDK 11+** אם עדיין לא מותקן
4. הורד **Android SDK** דרך B4A → Tools → Android SDK Manager

---

## שלב 2: יצירת פרויקט חדש

1. פתח B4A
2. **File → New → B4XPages Project**
3. שם פרויקט: `FamilyDiary`
4. Package: `com.yourname.familydiary`
5. שמור בתיקייה שתרצה

---

## שלב 3: ייבוא קבצי המקור

העתק את כל קבצי `.bas` לתוך תיקיית הפרויקט:
```
FamilyDiary/
├── Files/
├── Objects/
├── src/   ← העתק לכאן את כל התיקיות
│   ├── models/
│   ├── managers/
│   ├── ui/
│   ├── auth/
│   ├── config/
│   └── utils/
└── FamilyDiary.b4a
```

לאחר מכן ב-B4A:
**Project → Add Existing Module** → בחר כל קובץ `.bas` בנפרד

---

## שלב 4: ספריות נדרשות

ב-B4A: **Tools → Library Manager** → סמן את הספריות הבאות:

### ספריות Firebase (חובה):
- [ ] `FirebaseDatabase` — Realtime Database
- [ ] `FirebaseAuth` — כניסת משתמשים
- [ ] `FirebaseMessaging` — Push Notifications
- [ ] `GooglePlayServices` — נדרש ל-Google Sign-In

### ספריות UI (חובה):
- [ ] `XUI` — (B4X UI Library — מובנית בגרסאות חדשות)
- [ ] `B4XPages` — מנהל מסכים
- [ ] `B4XListView` — רשימות

### ספריות עזר:
- [ ] `JSON` — מובנית, לא צריך להוסיף
- [ ] `DateTime` — מובנית

---

## שלב 5: הגדרת Firebase

### 5א. יצירת פרויקט Firebase:
1. לך ל-https://console.firebase.google.com
2. **Add project** → שם: `family-diary`
3. השאר Google Analytics מופעל

### 5ב. הוספת אפליקציה אנדרואיד:
1. **Project Settings** → **Add app** → Android
2. Package name: `com.yourname.familydiary`
3. הורד `google-services.json`
4. **שים אותו בתיקיית הפרויקט** (ליד `FamilyDiary.b4a`)

### 5ג. הפעלת שירותים:
1. **Build** → **Realtime Database** → Create Database → Start in test mode
2. **Authentication** → **Sign-in method** → הפעל: Email/Password, Google
3. **Cloud Messaging** → מופעל אוטומטית

### 5ד. מלא את AppConfig.bas:
```vb
' src/config/AppConfig.bas
Public FIREBASE_API_KEY         As String = "AIzaSy..."     ' מ-Project Settings
Public FIREBASE_AUTH_DOMAIN     As String = "family-diary-xxxxx.firebaseapp.com"
Public FIREBASE_DATABASE_URL    As String = "https://family-diary-xxxxx-default-rtdb.firebaseio.com"
Public FIREBASE_PROJECT_ID      As String = "family-diary-xxxxx"
Public FIREBASE_STORAGE_BUCKET  As String = "family-diary-xxxxx.appspot.com"
Public FIREBASE_MESSAGING_ID    As String = "123456789012"
Public FIREBASE_APP_ID          As String = "1:123456789012:android:abc123..."
```

---

## שלב 6: AndroidManifest.xml

ב-B4A פתח **Project → Manifest Editor** והוסף:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>

<!-- FCM -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
</service>

<!-- Notification Channel (Android 8+) -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="hot_updates"/>
```

---

## שלב 7: Main Activity

צור קובץ `Main.bas` (או ערוך את הקובץ הראשי):

```vb
' Main.bas
Sub Process_Globals
    ' ריק — המשתנים הגלובליים ב-MainPage.bas
End Sub

Sub Globals
    Dim mMainPage As MainPage
End Sub

Sub Activity_Create(FirstTime As Boolean)
    Activity.LoadLayout("main")   ' layout ריק, MainPage בונה הכל דינמית
    
    mMainPage.Initialize(Activity)
End Sub

Sub Activity_Resume
    ' כאן ניתן לרענן FCM token
End Sub
```

---

## שלב 8: Layout בסיסי

ב-**B4A Designer** צור layout בשם `main.bal` עם:
- פאנל אחד ריק (`Panel1`) שממלא את כל המסך
- ה-`MainPage.Initialize(Panel1)` יבנה את כל שאר ה-UI בקוד

---

## שלב 9: הרצה

1. חבר מכשיר אנדרואיד (או הפעל אמולטור)
2. **Run → Run** (F5)
3. B4A מקמפל ומתקין על המכשיר

---

## שלב 10: Firebase Security Rules

1. Firebase Console → **Realtime Database → Rules**
2. העתק את תוכן `database/firebase_rules.json`
3. **Publish**

---

## שלב 11: Cloud Functions (אופציונלי בשלב ראשון)

```bash
npm install -g firebase-tools
firebase login
cd Family-diary/database
firebase init functions
# העתק את cloud_functions.js לתוך functions/index.js
firebase deploy --only functions
```

---

## בדיקה מהירה — האם Firebase עובד?

הוסף את הקוד הזה לאחר `mDbManager.Initialize(...)`:

```vb
' בדיקה: כתיבה ל-Firebase
Dim testRef As DatabaseReference = mDB.GetReference("test/ping")
testRef.SetValue("pong_" & DateTime.Now, "Main", "TestWrite")

Sub Main_TestWrite_Complete(success As Boolean)
    If success Then
        Log("✅ Firebase מחובר!")
    Else
        Log("❌ Firebase לא מחובר — בדוק את AppConfig")
    End If
End Sub
```

---

## סדר מומלץ לפיתוח

```
שבוע 1:
  ✅ Firebase + Auth
  ✅ יצירת אירוע ראשון (EventDialog)
  ✅ CalendarWeekView בסיסי

שבוע 2:
  ✅ TaskListView
  ✅ Hot Updates (הזזת אירוע)
  ✅ HotUpdateBanner

שבוע 3:
  ✅ Push Notifications
  ✅ אירועים חוזרים (RecurringEventManager)
  ✅ חיפוש

שבוע 4:
  ✅ StatsManager + Dashboard
  ✅ הצטרפות למשפחה (JoinCode)
  ✅ Polish + Bug fixes
```
