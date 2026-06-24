# מדריך הגדרה — Family Diary Phase 1

## מה בנינו ב-Phase 1

```
Family-diary/
├── database/
│   ├── firebase_schema.json     ← סכמת מסד הנתונים + הסברים
│   └── firebase_rules.json      ← כללי אבטחה ל-Firebase
└── src/
    ├── models/
    │   ├── CalendarEvent.bas    ← מודל אירוע (לב המערכת)
    │   ├── FamilyTask.bas       ← מודל משימה / שיעורי בית
    │   └── FamilyUser.bas       ← מודל משתמש
    ├── managers/
    │   ├── DatabaseManager.bas  ← כל גישה ל-Firebase
    │   ├── EventManager.bas     ← לוגיקת עסקים + סינון
    │   └── NotificationManager.bas ← מעקב Hot Updates
    └── utils/
        └── DateTimeUtils.bas    ← עזרי תאריך ושעה בעברית
```

---

## שלב 1: הגדרת Firebase

1. היכנס ל-[Firebase Console](https://console.firebase.google.com)
2. צור פרויקט חדש → שם: `family-diary`
3. הפעל **Realtime Database** (לא Firestore בשלב זה)
4. **Database Rules** → העתק את תוכן `firebase_rules.json`
5. **Project Settings** → העתק את כל פרטי ה-config

---

## שלב 2: מלא את הקונפיגורציה

פתח `DatabaseManager.bas` ומלא את `GetFirebaseConfig()`:

```
config.Put("apiKey",      "AIzaSy...")
config.Put("databaseURL", "https://family-diary-xxxxx-default-rtdb.firebaseio.com")
' ... כל שאר הנתונים מ-Firebase Console
```

---

## שלב 3: ייבוא לפרויקט B4X

### B4A (Android):
1. **Project → Add Existing Module** → בחר כל קובץ `.bas`
2. הוסף ל-`build.gradle`: `implementation 'com.google.firebase:firebase-database:20.x.x'`
3. הורד את `google-services.json` מ-Firebase → שים בתיקיית `app/`

### ספריות נדרשות:
- `FirebaseDatabase` — מ-B4A Firebase Bundle
- `JSON` — מובנית

---

## שלב 4: שימוש בסיסי

```vb
' ב-Activity או B4XPage הראשי:

Sub Process_Globals
    Dim mUser       As FamilyUser
    Dim mDbManager  As DatabaseManager
    Dim mEvtManager As EventManager
    Dim mDtUtils    As DateTimeUtils
End Sub

Sub Activity_Create(FirstTime As Boolean)
    ' הגדרת משתמש נוכחי
    mUser.Initialize
    mUser.Id       = FirebaseAuth.CurrentUser.Uid
    mUser.Name     = "יעל"
    mUser.Role     = "CHILD"
    mUser.FamilyId = "family_001"

    ' אתחול Managers
    mDtUtils.Initialize
    mDbManager.Initialize("family_001", mUser, "Main")
    mEvtManager.Initialize(mDbManager)

    ' התחל האזנה בזמן אמת
    mDbManager.StartListeningToEvents
    mDbManager.StartListeningToTasks
End Sub

' Firebase קרא אירועים → מגיע לכאן
Sub Main_EventsLoaded(events As List)
    mEvtManager.SetEvents(events)

    ' קבל אירועי היום
    Dim todayStr As String = mDtUtils.TsToDateStr(DateTime.Now)
    Dim todayEvents As List = mEvtManager.GetEventsForDate(todayStr)

    ' עדכן UI...
    UpdateCalendarUI(todayEvents)
End Sub

' Hot Update: הזז אירוע
Sub BtnMoveEvent_Click
    mEvtManager.MoveEvent("evt_xyz789", newStartTs, 0, "המאמן ביקש")
End Sub
```

---

## מבנה הנתונים — נקודות חשובות

### Hot Updates — איך זה עובד?

כל אירוע שומר **שני זמנים**:
- `original_time` — נשמר לצמיתות, לא משתנה לעולם
- `current_time` — הזמן האמיתי הנוכחי

כשמשתמש מזיז אירוע:
1. `current_time` מתעדכן ב-Firebase
2. Firebase מודיע לכל המכשירים תוך < 1 שנייה
3. ה-UI מציג אוטומטית: **"הוזז +30 דק'"** (מחושב מהפרש)
4. אם `original_time ≠ current_time` → `WasMoved() = True`

### קטגוריות וצבעים

| קטגוריה | עברית | צבע |
|----------|-------|-----|
| CHUGIM | חוגים | טורקיז #4ECDC4 |
| HOMEWORK | שיעורי בית | צהוב #FFE66D |
| FAMILY | משפחה | אדום-ורוד #FF6B6B |
| FRIENDS | חברים | ירוק #A8E6CF |
| OTHER | אחר | אפור #B0BEC5 |

---

## Phase 2 — מה הבא?

- [ ] `CalendarWeekView.bas` — תצוגת שבוע עם רשת שעות
- [ ] `TaskListView.bas` — רשימת משימות עם checkbox
- [ ] `HotUpdateBanner.bas` — באנר התראה בזמן אמת
- [ ] `EventDialog.bas` — טופס יצירה/עריכת אירוע
- [ ] Firebase Auth — כניסה עם Google
- [ ] Push Notifications — FCM לכל בני המשפחה
