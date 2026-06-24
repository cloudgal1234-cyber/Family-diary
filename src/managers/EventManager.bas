'=============================================================================
' EventManager.bas — לוגיקת עסקים לאירועים (Business Logic Layer)
' B4X Class Module
'
' תיאור: מקבל List של CalendarEvent מ-DatabaseManager,
'         ומספק פונקציות סינון, מיון, וקיבוץ לשימוש ה-UI.
'         ה-UI לא נוגע ישירות ב-DatabaseManager — הכל עובר כאן.
'=============================================================================
Sub Class_Globals

    Private mAllEvents As List   ' כל האירועים שנטענו
    Private mDb        As DatabaseManager

End Sub

Public Sub Initialize(db As DatabaseManager)
    mDb = db
    mAllEvents.Initialize
End Sub

'-----------------------------------------------------------------------------
' עדכון cache הפנימי (נקרא מה-UI כשמגיעים אירועים מ-Firebase)
'-----------------------------------------------------------------------------
Public Sub SetEvents(events As List)
    mAllEvents = events
End Sub

'=============================================================================
' שאלות לוח שנה — סינון ומיון
'=============================================================================

' אירועים ליום ספציפי, ממוינים לפי שעת התחלה
Public Sub GetEventsForDate(dateStr As String) As List
    Dim result As List
    result.Initialize

    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.DateStr = dateStr Then
            result.Add(evt)
        End If
    Next

    Return SortEventsByTime(result)
End Sub

' אירועים לשבוע שלם (startDateStr עד + 6 ימים)
Public Sub GetEventsForWeek(startDateStr As String) As Map
    Dim weekMap As Map
    weekMap.Initialize

    Dim startTs As Long = DateStrToTimestamp(startDateStr)
    For day = 0 To 6
        Dim dayTs  As Long   = startTs + (day * 86400000)
        Dim dayStr As String = TimestampToDateStr(dayTs)
        weekMap.Put(dayStr, GetEventsForDate(dayStr))
    Next

    Return weekMap
End Sub

' אירועים לפי קטגוריה
Public Sub GetEventsByCategory(category As String) As List
    Dim result As List
    result.Initialize
    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.Category = category Then result.Add(evt)
    Next
    Return result
End Sub

' רק אירועים עם עדכון (Hot Updates) — לתצוגת "מה השתנה?"
Public Sub GetChangedEvents() As List
    Dim result As List
    result.Initialize
    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.WasMoved() Or evt.IsCanceled() Then
            result.Add(evt)
        End If
    Next
    Return result
End Sub

' חיפוש חופשי לפי כותרת
Public Sub SearchEvents(query As String) As List
    Dim result As List
    result.Initialize
    Dim q As String = query.ToLowerCase
    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.Title.ToLowerCase.Contains(q) Or evt.Location.ToLowerCase.Contains(q) Then
            result.Add(evt)
        End If
    Next
    Return result
End Sub

'=============================================================================
' Hot Update — כל הלוגיקה של הזזת אירועים
'=============================================================================

' הזזת אירוע: מחשבת זמן חדש ושולחת עדכון
Public Sub MoveEvent(eventId As String, newStartTs As Long, durationKeepMs As Long, note As String)
    Dim evt As CalendarEvent = mDb.GetCachedEvent(eventId)
    If evt.Id = "" Then Return

    Dim duration As Long = evt.CurrentEndTs - evt.CurrentStartTs
    If durationKeepMs > 0 Then duration = durationKeepMs

    mDb.UpdateEventStatus(eventId, "MOVED", newStartTs, newStartTs + duration, note)
End Sub

' ביטול אירוע
Public Sub CancelEvent(eventId As String, reason As String)
    Dim evt As CalendarEvent = mDb.GetCachedEvent(eventId)
    If evt.Id = "" Then Return
    mDb.UpdateEventStatus(eventId, "CANCELED", evt.CurrentStartTs, evt.CurrentEndTs, reason)
End Sub

' החזרת אירוע לזמן המקורי
Public Sub ResetToOriginalTime(eventId As String)
    Dim evt As CalendarEvent = mDb.GetCachedEvent(eventId)
    If evt.Id = "" Then Return
    Dim duration As Long = evt.OriginalEndTs - evt.OriginalStartTs
    mDb.UpdateEventStatus(eventId, "ON_TIME", evt.OriginalStartTs, evt.OriginalStartTs + duration, "הוחזר לזמן המקורי")
End Sub

'=============================================================================
' עזרי מיון ותאריכים
'=============================================================================

Private Sub SortEventsByTime(events As List) As List
    ' מיון בועות פשוט לפי CurrentStartTs
    Dim n As Int = events.Size
    For i = 0 To n - 2
        For j = 0 To n - i - 2
            Dim a As CalendarEvent = events.Get(j)
            Dim b As CalendarEvent = events.Get(j + 1)
            If a.CurrentStartTs > b.CurrentStartTs Then
                events.Set(j,     b)
                events.Set(j + 1, a)
            End If
        Next
    Next
    Return events
End Sub

' "2024-11-15" → Timestamp (UTC midnight)
Private Sub DateStrToTimestamp(dateStr As String) As Long
    Dim parts() As String = Regex.Split("-", dateStr)
    If parts.Length < 3 Then Return 0
    Dim oldFormat As String = DateTime.DateFormat
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim ts As Long = DateTime.DateParse(dateStr)
    DateTime.DateFormat = oldFormat
    Return ts
End Sub

' Timestamp → "2024-11-15"
Private Sub TimestampToDateStr(ts As Long) As String
    Dim oldFormat As String = DateTime.DateFormat
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim s As String = DateTime.Date(ts)
    DateTime.DateFormat = oldFormat
    Return s
End Sub

'=============================================================================
' סטטיסטיקות — לדשבורד
'=============================================================================

Public Sub GetWeekStats(startDateStr As String) As Map
    Dim stats As Map
    stats.Initialize
    stats.Put("total",    0)
    stats.Put("moved",    0)
    stats.Put("canceled", 0)
    stats.Put("on_time",  0)

    Dim weekEvents As Map = GetEventsForWeek(startDateStr)
    For d = 0 To 6
        Dim dayKey As String  = weekEvents.GetKeyAt(d)
        Dim dayList As List   = weekEvents.Get(dayKey)
        For i = 0 To dayList.Size - 1
            Dim evt As CalendarEvent = dayList.Get(i)
            stats.Put("total", CInt(stats.Get("total")) + 1)
            Select Case evt.Status
                Case "MOVED", "RESCHEDULED" : stats.Put("moved",    CInt(stats.Get("moved"))    + 1)
                Case "CANCELED"             : stats.Put("canceled", CInt(stats.Get("canceled")) + 1)
                Case Else                   : stats.Put("on_time",  CInt(stats.Get("on_time"))  + 1)
            End Select
        Next
    Next

    Return stats
End Sub
