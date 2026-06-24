'=============================================================================
' CalendarEvent.bas — מודל אירוע ביומן המשפחה
' B4X Class Module (תואם B4A / B4J / B4i)
'
' תיאור: מייצג אירוע יחיד (חוג, פגישה משפחתית, וכד')
'         כולל תמיכה מלאה ב-Hot Updates — מעקב שינויי זמן וסטטוס
'=============================================================================
Sub Class_Globals

    '--- מזהה ייחודי ---
    Public Id          As String   ' evt_xyz789 (Firebase push key)
    Public FamilyId    As String   ' מזהה המשפחה להשתייכות

    '--- תוכן הבסיסי ---
    Public Title       As String   ' שם האירוע, למשל "חוג שחייה"
    Public Description As String   ' פרטים נוספים
    Public Location    As String   ' מיקום

    '--- קטגוריה וצבע ---
    Public Category    As String   ' ראה CATEGORY_* למטה
    Public ColorHex    As String   ' צבע עקיפה (ריק = צבע ברירת מחדל של הקטגוריה)

    '--- זמנים: מקורי מול נוכחי (ליבת מערכת ה-Hot Updates) ---
    Public OriginalStartTs  As Long   ' Timestamp מקורי (ms)
    Public OriginalEndTs    As Long
    Public CurrentStartTs   As Long   ' Timestamp נוכחי — אם שונה, זו "הזזה"
    Public CurrentEndTs     As Long
    Public DateStr          As String ' "2024-11-15" לסינון יומי מהיר

    '--- סטטוס ועדכון ---
    Public Status      As String   ' ראה STATUS_* למטה
    Public StatusNote  As String   ' הסבר קצר, למשל "המאמן ביקש להזיז"
    Public UpdatedBy   As String   ' userId של מי שעדכן לאחרונה
    Public CreatedBy   As String
    Public CreatedAt   As Long
    Public UpdatedAt   As Long

    '--- משתתפים ---
    Public Attendees   As List     ' רשימת userIds

    '--- חזרתיות ---
    Public IsRecurring      As Boolean
    Public RecurrenceFreq   As String   ' DAILY / WEEKLY / MONTHLY
    Public RecurrenceDays   As List     ' [0,1,2...6] עבור ימי שבוע
    Public RecurrenceEndDate As String  ' "2025-06-30"

    '--- התראות ---
    Public NotifyBeforeMinutes As Int
    Public NotifyEnabled       As Boolean

    Public IsDeleted   As Boolean

End Sub

'-----------------------------------------------------------------------------
' אתחול ערכי ברירת מחדל
'-----------------------------------------------------------------------------
Public Sub Initialize()
    Id                    = ""
    FamilyId              = ""
    Title                 = ""
    Description           = ""
    Location              = ""
    Category              = CATEGORY_OTHER
    ColorHex              = ""
    OriginalStartTs       = 0
    OriginalEndTs         = 0
    CurrentStartTs        = 0
    CurrentEndTs          = 0
    DateStr               = ""
    Status                = STATUS_ON_TIME
    StatusNote            = ""
    UpdatedBy             = ""
    CreatedBy             = ""
    CreatedAt             = 0
    UpdatedAt             = 0
    Attendees.Initialize
    IsRecurring           = False
    RecurrenceFreq        = ""
    RecurrenceDays.Initialize
    RecurrenceEndDate     = ""
    NotifyBeforeMinutes   = 30
    NotifyEnabled         = True
    IsDeleted             = False
End Sub

'-----------------------------------------------------------------------------
' בנייה מ-Map (פריט שהגיע מ-Firebase)
'-----------------------------------------------------------------------------
Public Sub FromMap(m As Map)
    If m.IsInitialized = False Then Return

    Id               = MapGetStr(m, "id", "")
    FamilyId         = MapGetStr(m, "family_id", "")
    Title            = MapGetStr(m, "title", "")
    Description      = MapGetStr(m, "description", "")
    Location         = MapGetStr(m, "location", "")
    Category         = MapGetStr(m, "category", CATEGORY_OTHER)
    ColorHex         = MapGetStr(m, "color_override", "")
    Status           = MapGetStr(m, "status", STATUS_ON_TIME)
    StatusNote       = MapGetStr(m, "status_note", "")
    UpdatedBy        = MapGetStr(m, "updated_by", "")
    CreatedBy        = MapGetStr(m, "created_by", "")
    IsDeleted        = MapGetBool(m, "is_deleted", False)

    CreatedAt        = MapGetLong(m, "created_at", 0)
    UpdatedAt        = MapGetLong(m, "updated_at", 0)

    ' --- זמן מקורי ---
    If m.ContainsKey("original_time") Then
        Dim ot As Map = m.Get("original_time")
        OriginalStartTs = MapGetLong(ot, "start", 0)
        OriginalEndTs   = MapGetLong(ot, "end", 0)
        DateStr         = MapGetStr(ot, "date", "")
    End If

    ' --- זמן נוכחי ---
    If m.ContainsKey("current_time") Then
        Dim ct As Map = m.Get("current_time")
        CurrentStartTs = MapGetLong(ct, "start", 0)
        CurrentEndTs   = MapGetLong(ct, "end", 0)
        If DateStr = "" Then DateStr = MapGetStr(ct, "date", "")
    End If

    ' --- משתתפים ---
    Attendees.Initialize
    If m.ContainsKey("attendees") Then
        Dim attMap As Map = m.Get("attendees")
        For i = 0 To attMap.Size - 1
            Attendees.Add(attMap.GetValueAt(i))
        Next
    End If

    ' --- חזרתיות ---
    If m.ContainsKey("recurrence") Then
        Dim rec As Map = m.Get("recurrence")
        IsRecurring      = MapGetBool(rec, "is_recurring", False)
        RecurrenceFreq   = MapGetStr(rec, "frequency", "")
        RecurrenceEndDate = MapGetStr(rec, "end_date", "")
        RecurrenceDays.Initialize
        If rec.ContainsKey("days_of_week") Then
            Dim daysMap As Map = rec.Get("days_of_week")
            For i = 0 To daysMap.Size - 1
                RecurrenceDays.Add(daysMap.GetValueAt(i))
            Next
        End If
    End If

    ' --- התראות ---
    If m.ContainsKey("notification") Then
        Dim notif As Map = m.Get("notification")
        NotifyBeforeMinutes = MapGetInt(notif, "before_minutes", 30)
        NotifyEnabled       = MapGetBool(notif, "enabled", True)
    End If

End Sub

'-----------------------------------------------------------------------------
' המרה ל-Map לשמירה ב-Firebase
'-----------------------------------------------------------------------------
Public Sub ToMap() As Map
    Dim m As Map
    m.Initialize

    m.Put("id",          Id)
    m.Put("family_id",   FamilyId)
    m.Put("title",       Title)
    m.Put("description", Description)
    m.Put("location",    Location)
    m.Put("category",    Category)
    m.Put("status",      Status)
    m.Put("status_note", StatusNote)
    m.Put("updated_by",  UpdatedBy)
    m.Put("created_by",  CreatedBy)
    m.Put("created_at",  CreatedAt)
    m.Put("updated_at",  UpdatedAt)
    m.Put("is_deleted",  IsDeleted)

    If ColorHex <> "" Then m.Put("color_override", ColorHex)

    ' --- זמן מקורי ---
    Dim ot As Map
    ot.Initialize
    ot.Put("start", OriginalStartTs)
    ot.Put("end",   OriginalEndTs)
    ot.Put("date",  DateStr)
    m.Put("original_time", ot)

    ' --- זמן נוכחי ---
    Dim ct As Map
    ct.Initialize
    ct.Put("start", CurrentStartTs)
    ct.Put("end",   CurrentEndTs)
    ct.Put("date",  DateStr)
    m.Put("current_time", ct)

    ' --- חזרתיות ---
    Dim rec As Map
    rec.Initialize
    rec.Put("is_recurring", IsRecurring)
    rec.Put("frequency",    RecurrenceFreq)
    rec.Put("end_date",     RecurrenceEndDate)
    Dim daysMap As Map
    daysMap.Initialize
    For i = 0 To RecurrenceDays.Size - 1
        daysMap.Put(i, RecurrenceDays.Get(i))
    Next
    rec.Put("days_of_week", daysMap)
    m.Put("recurrence", rec)

    ' --- התראות ---
    Dim notif As Map
    notif.Initialize
    notif.Put("before_minutes", NotifyBeforeMinutes)
    notif.Put("enabled",        NotifyEnabled)
    m.Put("notification", notif)

    Return m
End Sub

'-----------------------------------------------------------------------------
' שאלות עסקיות על האירוע
'-----------------------------------------------------------------------------

' האם האירוע הוזז מהזמן המקורי?
Public Sub WasMoved() As Boolean
    Return CurrentStartTs <> OriginalStartTs Or CurrentEndTs <> OriginalEndTs
End Sub

' האם האירוע בוטל?
Public Sub IsCanceled() As Boolean
    Return Status = STATUS_CANCELED
End Sub

' כמה דקות האירוע הוזז? (חיובי = קדימה, שלילי = אחורה)
Public Sub GetShiftMinutes() As Long
    Return (CurrentStartTs - OriginalStartTs) / 60000
End Sub

' תווית Hot Update לתצוגה ("הוזז 30 דק'", "בוטל", "בזמן")
Public Sub GetStatusLabel() As String
    Select Case Status
        Case STATUS_CANCELED
            Return "בוטל"
        Case STATUS_MOVED, STATUS_RESCHEDULED
            Dim shift As Long = GetShiftMinutes()
            If shift > 0 Then
                Return "הוזז +" & shift & " דק'"
            Else If shift < 0 Then
                Return "הוזז " & shift & " דק'"
            Else
                Return "שונה"
            End If
        Case STATUS_POSTPONED
            Return "נדחה"
        Case Else
            Return "בזמן"
    End Select
End Sub

' צבע הקטגוריה (ברירת מחדל לפי קטגוריה)
Public Sub GetDisplayColor() As String
    If ColorHex <> "" Then Return ColorHex
    Select Case Category
        Case CATEGORY_CHUGIM   : Return "#4ECDC4"   ' טורקיז — חוגים
        Case CATEGORY_HOMEWORK  : Return "#FFE66D"   ' צהוב — שיעורי בית
        Case CATEGORY_FAMILY    : Return "#FF6B6B"   ' אדום-ורוד — משפחה
        Case CATEGORY_FRIENDS   : Return "#A8E6CF"   ' ירוק — חברים
        Case Else               : Return "#B0BEC5"   ' אפור — אחר
    End Select
End Sub

'=============================================================================
' קבועים (Enums) — קטגוריות
'=============================================================================
Public Sub CATEGORY_CHUGIM()  As String : Return "CHUGIM"   : End Sub
Public Sub CATEGORY_HOMEWORK() As String : Return "HOMEWORK" : End Sub
Public Sub CATEGORY_FAMILY()   As String : Return "FAMILY"   : End Sub
Public Sub CATEGORY_FRIENDS()  As String : Return "FRIENDS"  : End Sub
Public Sub CATEGORY_OTHER()    As String : Return "OTHER"     : End Sub

'=============================================================================
' קבועים — סטטוסים
'=============================================================================
Public Sub STATUS_ON_TIME()     As String : Return "ON_TIME"     : End Sub
Public Sub STATUS_MOVED()       As String : Return "MOVED"       : End Sub
Public Sub STATUS_CANCELED()    As String : Return "CANCELED"    : End Sub
Public Sub STATUS_RESCHEDULED() As String : Return "RESCHEDULED" : End Sub
Public Sub STATUS_POSTPONED()   As String : Return "POSTPONED"   : End Sub

'=============================================================================
' עוזרי Map פנימיים (helper methods)
'=============================================================================
Private Sub MapGetStr(m As Map, key As String, defaultVal As String) As String
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub

Private Sub MapGetBool(m As Map, key As String, defaultVal As Boolean) As Boolean
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub

Private Sub MapGetLong(m As Map, key As String, defaultVal As Long) As Long
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub

Private Sub MapGetInt(m As Map, key As String, defaultVal As Int) As Int
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub
