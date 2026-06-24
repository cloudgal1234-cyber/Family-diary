'=============================================================================
' AppConfig.bas — קונפיגורציה מרכזית של האפליקציה
' B4X Class Module (Singleton — מאותחל פעם אחת ב-Process_Globals)
'
' כל הקבועים, הצבעים, ופרטי Firebase במקום אחד.
'=============================================================================
Sub Class_Globals

    '--- Firebase ---
    Public FIREBASE_API_KEY         As String = "YOUR_API_KEY"
    Public FIREBASE_AUTH_DOMAIN     As String = "YOUR_PROJECT.firebaseapp.com"
    Public FIREBASE_DATABASE_URL    As String = "https://YOUR_PROJECT-default-rtdb.firebaseio.com"
    Public FIREBASE_PROJECT_ID      As String = "YOUR_PROJECT_ID"
    Public FIREBASE_STORAGE_BUCKET  As String = "YOUR_PROJECT.appspot.com"
    Public FIREBASE_MESSAGING_ID    As String = "YOUR_SENDER_ID"
    Public FIREBASE_APP_ID          As String = "YOUR_APP_ID"

    '--- אפליקציה ---
    Public APP_VERSION              As String = "2.0.0"
    Public APP_NAME                 As String = "יומן משפחה"
    Public DEFAULT_FAMILY_ID        As String = ""   ' מוזן אחרי כניסה
    Public DEFAULT_REMINDER_MINUTES As Int    = 30
    Public CACHE_TTL_MS             As Long   = 300000  ' 5 דקות

    '--- צבעי קטגוריות ---
    Public COLOR_CHUGIM   As String = "#4ECDC4"   ' טורקיז
    Public COLOR_HOMEWORK As String = "#FFE66D"   ' צהוב
    Public COLOR_FAMILY   As String = "#FF6B6B"   ' אדום-ורוד
    Public COLOR_FRIENDS  As String = "#A8E6CF"   ' ירוק בהיר
    Public COLOR_OTHER    As String = "#B0BEC5"   ' אפור

    '--- צבעי סטטוס ---
    Public COLOR_STATUS_ON_TIME     As String = "#2ECC71"   ' ירוק
    Public COLOR_STATUS_MOVED       As String = "#F39C12"   ' כתום
    Public COLOR_STATUS_CANCELED    As String = "#E74C3C"   ' אדום
    Public COLOR_STATUS_POSTPONED   As String = "#9B59B6"   ' סגול

    '--- צבעי עדיפות משימה ---
    Public COLOR_PRIO_URGENT As String = "#FF3B30"
    Public COLOR_PRIO_HIGH   As String = "#FF9500"
    Public COLOR_PRIO_MEDIUM As String = "#FFCC00"
    Public COLOR_PRIO_LOW    As String = "#34C759"

    '--- ממדי UI ---
    Public CELL_HEIGHT_DP          As Int = 60    ' גובה תא שעה בתצוגה יומית
    Public EVENT_BLOCK_MIN_HEIGHT  As Int = 24
    Public WEEK_HEADER_HEIGHT_DP   As Int = 48
    Public SIDEBAR_WIDTH_DP        As Int = 52    ' עמודת שעות
    Public BANNER_HEIGHT_DP        As Int = 56
    Public TASK_ROW_HEIGHT_DP      As Int = 64

    '--- RTL ---
    Public IS_RTL As Boolean = True

End Sub

Public Sub Initialize()
    ' ערכי ברירת מחדל כבר מוגדרים בהצהרות למעלה
End Sub

' קבל Map מוכן לשליחה ל-Firebase
Public Sub GetFirebaseConfig() As Map
    Dim cfg As Map
    cfg.Initialize
    cfg.Put("apiKey",            FIREBASE_API_KEY)
    cfg.Put("authDomain",        FIREBASE_AUTH_DOMAIN)
    cfg.Put("databaseURL",       FIREBASE_DATABASE_URL)
    cfg.Put("projectId",         FIREBASE_PROJECT_ID)
    cfg.Put("storageBucket",     FIREBASE_STORAGE_BUCKET)
    cfg.Put("messagingSenderId", FIREBASE_MESSAGING_ID)
    cfg.Put("appId",             FIREBASE_APP_ID)
    Return cfg
End Sub

' צבע לפי שם קטגוריה
Public Sub GetCategoryColor(category As String) As String
    Select Case category
        Case "CHUGIM"   : Return COLOR_CHUGIM
        Case "HOMEWORK" : Return COLOR_HOMEWORK
        Case "FAMILY"   : Return COLOR_FAMILY
        Case "FRIENDS"  : Return COLOR_FRIENDS
        Case Else       : Return COLOR_OTHER
    End Select
End Sub

' שם עברי לקטגוריה
Public Sub GetCategoryName(category As String) As String
    Select Case category
        Case "CHUGIM"   : Return "חוגים"
        Case "HOMEWORK" : Return "שיעורי בית"
        Case "FAMILY"   : Return "משפחה"
        Case "FRIENDS"  : Return "חברים"
        Case Else       : Return "אחר"
    End Select
End Sub

' שם עברי לסטטוס
Public Sub GetStatusName(status As String) As String
    Select Case status
        Case "ON_TIME"     : Return "בזמן"
        Case "MOVED"       : Return "הוזז"
        Case "CANCELED"    : Return "בוטל"
        Case "RESCHEDULED" : Return "נקבע מחדש"
        Case "POSTPONED"   : Return "נדחה"
        Case Else          : Return status
    End Select
End Sub

' צבע לפי סטטוס
Public Sub GetStatusColor(status As String) As String
    Select Case status
        Case "ON_TIME"                  : Return COLOR_STATUS_ON_TIME
        Case "MOVED", "RESCHEDULED"     : Return COLOR_STATUS_MOVED
        Case "CANCELED"                 : Return COLOR_STATUS_CANCELED
        Case "POSTPONED"                : Return COLOR_STATUS_POSTPONED
        Case Else                       : Return COLOR_OTHER
    End Select
End Sub
