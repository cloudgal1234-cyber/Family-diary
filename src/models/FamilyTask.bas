'=============================================================================
' FamilyTask.bas — מודל משימה / שיעורי בית
' B4X Class Module
'
' תיאור: מייצג משימה אחת — שיעורי בית, פרויקט, או כל To-Do משפחתי.
'         תומך ב-time-blocking (חסימת זמן לעשיית המשימה) וב-checkbox מהיר.
'=============================================================================
Sub Class_Globals

    Public Id          As String   ' task_hw001
    Public FamilyId    As String

    '--- תוכן ---
    Public Title       As String   ' "שיעורי בית — חשבון עמוד 45"
    Public Subject     As String   ' "מתמטיקה" (רלוונטי לשיעורי בית)
    Public Description As String   ' פרטים נוספים
    Public Notes       As String   ' הערות חופשיות

    '--- עדיפות וסטטוס ---
    Public Priority    As String   ' ראה PRIORITY_*
    Public Status      As String   ' ראה TASK_STATUS_*

    '--- מועד הגשה ---
    Public DueDateStr  As String   ' "2024-11-16"
    Public DueTimeStr  As String   ' "18:00"
    Public DueTs       As Long     ' Timestamp לסינון וסידור

    '--- חסימת זמן (Time Block) ---
    ' מאפשרת לקבוע: "אעשה את שיעורי הבית 16:00–17:00"
    Public TimeBlockEnabled    As Boolean
    Public TimeBlockStartTs    As Long
    Public TimeBlockDurationMin As Int

    '--- שיוך ---
    Public AssignedTo  As String   ' userId
    Public CreatedBy   As String
    Public UpdatedBy   As String
    Public CreatedAt   As Long
    Public UpdatedAt   As Long
    Public CompletedAt As Long     ' 0 = לא הושלם

    Public IsDeleted   As Boolean

End Sub

'-----------------------------------------------------------------------------
' אתחול ערכי ברירת מחדל
'-----------------------------------------------------------------------------
Public Sub Initialize()
    Id                     = ""
    FamilyId               = ""
    Title                  = ""
    Subject                = ""
    Description            = ""
    Notes                  = ""
    Priority               = PRIORITY_MEDIUM
    Status                 = TASK_STATUS_PENDING
    DueDateStr             = ""
    DueTimeStr             = ""
    DueTs                  = 0
    TimeBlockEnabled       = False
    TimeBlockStartTs       = 0
    TimeBlockDurationMin   = 0
    AssignedTo             = ""
    CreatedBy              = ""
    UpdatedBy              = ""
    CreatedAt              = 0
    UpdatedAt              = 0
    CompletedAt            = 0
    IsDeleted              = False
End Sub

'-----------------------------------------------------------------------------
' בנייה מ-Map (Firebase)
'-----------------------------------------------------------------------------
Public Sub FromMap(m As Map)
    If m.IsInitialized = False Then Return

    Id          = MapGetStr(m, "id", "")
    FamilyId    = MapGetStr(m, "family_id", "")
    Title       = MapGetStr(m, "title", "")
    Subject     = MapGetStr(m, "subject", "")
    Description = MapGetStr(m, "description", "")
    Notes       = MapGetStr(m, "notes", "")
    Priority    = MapGetStr(m, "priority", PRIORITY_MEDIUM)
    Status      = MapGetStr(m, "status", TASK_STATUS_PENDING)
    AssignedTo  = MapGetStr(m, "assigned_to", "")
    CreatedBy   = MapGetStr(m, "created_by", "")
    UpdatedBy   = MapGetStr(m, "updated_by", "")
    CreatedAt   = MapGetLong(m, "created_at", 0)
    UpdatedAt   = MapGetLong(m, "updated_at", 0)
    CompletedAt = MapGetLong(m, "completed_at", 0)
    IsDeleted   = MapGetBool(m, "is_deleted", False)

    If m.ContainsKey("due") Then
        Dim due As Map = m.Get("due")
        DueDateStr = MapGetStr(due, "date", "")
        DueTimeStr = MapGetStr(due, "time", "")
        DueTs      = MapGetLong(due, "timestamp", 0)
    End If

    If m.ContainsKey("time_block") Then
        Dim tb As Map = m.Get("time_block")
        TimeBlockEnabled     = MapGetBool(tb, "enabled", False)
        TimeBlockStartTs     = MapGetLong(tb, "start_timestamp", 0)
        TimeBlockDurationMin = MapGetInt(tb, "duration_minutes", 0)
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
    m.Put("subject",     Subject)
    m.Put("description", Description)
    m.Put("notes",       Notes)
    m.Put("priority",    Priority)
    m.Put("status",      Status)
    m.Put("assigned_to", AssignedTo)
    m.Put("created_by",  CreatedBy)
    m.Put("updated_by",  UpdatedBy)
    m.Put("created_at",  CreatedAt)
    m.Put("updated_at",  UpdatedAt)
    m.Put("completed_at", CompletedAt)
    m.Put("is_deleted",  IsDeleted)

    Dim due As Map
    due.Initialize
    due.Put("date",      DueDateStr)
    due.Put("time",      DueTimeStr)
    due.Put("timestamp", DueTs)
    m.Put("due", due)

    Dim tb As Map
    tb.Initialize
    tb.Put("enabled",          TimeBlockEnabled)
    tb.Put("start_timestamp",  TimeBlockStartTs)
    tb.Put("duration_minutes", TimeBlockDurationMin)
    m.Put("time_block", tb)

    Return m
End Sub

'-----------------------------------------------------------------------------
' פעולות עסקיות
'-----------------------------------------------------------------------------

' סמן כהושלם — מעדכן גם timestamp ו-updatedBy
Public Sub MarkDone(byUserId As String)
    Status      = TASK_STATUS_DONE
    CompletedAt = DateTime.Now
    UpdatedBy   = byUserId
    UpdatedAt   = DateTime.Now
End Sub

' בטל סימון הושלם
Public Sub MarkPending(byUserId As String)
    Status      = TASK_STATUS_PENDING
    CompletedAt = 0
    UpdatedBy   = byUserId
    UpdatedAt   = DateTime.Now
End Sub

Public Sub IsDone() As Boolean
    Return Status = TASK_STATUS_DONE
End Sub

' האם המשימה פגת תוקף (עבר מועד ההגשה)?
Public Sub IsOverdue() As Boolean
    If IsDone() Then Return False
    If DueTs = 0 Then Return False
    Return DateTime.Now > DueTs
End Sub

' צבע עדיפות לתצוגה
Public Sub GetPriorityColor() As String
    Select Case Priority
        Case PRIORITY_URGENT : Return "#FF3B30"   ' אדום
        Case PRIORITY_HIGH   : Return "#FF9500"   ' כתום
        Case PRIORITY_MEDIUM : Return "#FFCC00"   ' צהוב
        Case Else            : Return "#34C759"   ' ירוק
    End Select
End Sub

' תווית עדיפות בעברית
Public Sub GetPriorityLabel() As String
    Select Case Priority
        Case PRIORITY_URGENT : Return "דחוף!"
        Case PRIORITY_HIGH   : Return "גבוה"
        Case PRIORITY_MEDIUM : Return "בינוני"
        Case Else            : Return "נמוך"
    End Select
End Sub

'=============================================================================
' קבועים — עדיפויות
'=============================================================================
Public Sub PRIORITY_LOW()    As String : Return "LOW"    : End Sub
Public Sub PRIORITY_MEDIUM() As String : Return "MEDIUM" : End Sub
Public Sub PRIORITY_HIGH()   As String : Return "HIGH"   : End Sub
Public Sub PRIORITY_URGENT() As String : Return "URGENT" : End Sub

'=============================================================================
' קבועים — סטטוסי משימה
'=============================================================================
Public Sub TASK_STATUS_PENDING()     As String : Return "PENDING"     : End Sub
Public Sub TASK_STATUS_IN_PROGRESS() As String : Return "IN_PROGRESS" : End Sub
Public Sub TASK_STATUS_DONE()        As String : Return "DONE"        : End Sub
Public Sub TASK_STATUS_SKIPPED()     As String : Return "SKIPPED"     : End Sub

'=============================================================================
' עוזרי Map פנימיים
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
