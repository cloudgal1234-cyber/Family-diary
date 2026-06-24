'=============================================================================
' SearchManager.bas — חיפוש מלא בכל האירועים והמשימות
' B4X Class Module
'
' תיאור: חיפוש טקסט חופשי על פני אירועים, משימות, ומיקומים.
'         תומך ב: חיפוש מהיר, סינון לפי קטגוריה, וסינון לפי תאריך.
'         מחזיר תוצאות מדורגות לפי רלוונטיות.
'=============================================================================
Sub Class_Globals

    Private mAllEvents As List
    Private mAllTasks  As List
    Private mDtUtils   As DateTimeUtils

End Sub

Public Sub Initialize()
    mDtUtils.Initialize
    mAllEvents.Initialize
    mAllTasks.Initialize
End Sub

Public Sub SetData(events As List, tasks As List)
    mAllEvents = events
    mAllTasks  = tasks
End Sub

'-----------------------------------------------------------------------------
' חיפוש כולל
' מחזיר Map: {"events": List, "tasks": List, "total": Int}
'-----------------------------------------------------------------------------
Public Sub Search(query As String) As Map
    Dim result As Map
    result.Initialize

    Dim q As String = query.Trim.ToLowerCase

    Dim matchedEvents As List = SearchEvents(q, "", "")
    Dim matchedTasks  As List = SearchTasks(q, "", "")

    result.Put("events", matchedEvents)
    result.Put("tasks",  matchedTasks)
    result.Put("total",  matchedEvents.Size + matchedTasks.Size)
    result.Put("query",  query)

    Return result
End Sub

'-----------------------------------------------------------------------------
' חיפוש אירועים
' category: "" = הכל | "CHUGIM" | "HOMEWORK" | "FAMILY" | "FRIENDS"
' dateStr:  "" = הכל | "2024-11-15" = יום ספציפי
'-----------------------------------------------------------------------------
Public Sub SearchEvents(query As String, category As String, dateStr As String) As List
    Dim result  As List
    result.Initialize
    Dim scored  As List
    scored.Initialize

    Dim q As String = query.ToLowerCase

    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)

        ' סינון קטגוריה
        If category <> "" And evt.Category <> category Then Continue

        ' סינון תאריך
        If dateStr <> "" And evt.DateStr <> dateStr Then Continue

        ' חישוב ציון רלוונטיות
        Dim score As Int = ScoreEvent(evt, q)
        If score > 0 Then
            Dim entry As Map
            entry.Initialize
            entry.Put("event", evt)
            entry.Put("score", score)
            scored.Add(entry)
        End If
    Next

    ' מיין לפי ציון יורד
    SortByScore(scored)
    For i = 0 To scored.Size - 1
        Dim entry As Map = scored.Get(i)
        result.Add(entry.Get("event"))
    Next

    Return result
End Sub

Public Sub SearchTasks(query As String, priority As String, assignedTo As String) As List
    Dim result As List
    result.Initialize
    Dim q As String = query.ToLowerCase

    For i = 0 To mAllTasks.Size - 1
        Dim task As FamilyTask = mAllTasks.Get(i)

        If priority <> "" And task.Priority <> priority Then Continue
        If assignedTo <> "" And task.AssignedTo <> assignedTo Then Continue

        Dim score As Int = ScoreTask(task, q)
        If score > 0 Then result.Add(task)
    Next

    Return result
End Sub

'-----------------------------------------------------------------------------
' חישוב ציון: כמה הפריט מתאים לשאילתה
'-----------------------------------------------------------------------------
Private Sub ScoreEvent(evt As CalendarEvent, q As String) As Int
    If q = "" Then Return 1   ' חיפוש ריק → הכל
    Dim score As Int = 0

    If evt.Title.ToLowerCase.Contains(q)       Then score = score + 10
    If evt.Title.ToLowerCase.StartsWith(q)     Then score = score + 5
    If evt.Location.ToLowerCase.Contains(q)    Then score = score + 4
    If evt.Description.ToLowerCase.Contains(q) Then score = score + 2
    If evt.StatusNote.ToLowerCase.Contains(q)  Then score = score + 1

    ' בונוס לאירועים קרובים
    Dim daysUntil As Long = (evt.CurrentStartTs - DateTime.Now) / 86400000
    If daysUntil >= 0 And daysUntil <= 7 Then score = score + 3

    Return score
End Sub

Private Sub ScoreTask(task As FamilyTask, q As String) As Int
    If q = "" Then Return 1
    Dim score As Int = 0

    If task.Title.ToLowerCase.Contains(q)       Then score = score + 10
    If task.Subject.ToLowerCase.Contains(q)     Then score = score + 6
    If task.Description.ToLowerCase.Contains(q) Then score = score + 2
    If task.Notes.ToLowerCase.Contains(q)       Then score = score + 1

    Return score
End Sub

Private Sub SortByScore(list As List)
    Dim n As Int = list.Size
    For i = 0 To n - 2
        For j = 0 To n - i - 2
            Dim a As Map = list.Get(j)
            Dim b As Map = list.Get(j + 1)
            If CInt(a.Get("score")) < CInt(b.Get("score")) Then
                list.Set(j,     b)
                list.Set(j + 1, a)
            End If
        Next
    Next
End Sub

'-----------------------------------------------------------------------------
' הצעות חיפוש (Autocomplete)
'-----------------------------------------------------------------------------
Public Sub GetSuggestions(partialQuery As String) As List
    Dim suggestions As List
    suggestions.Initialize
    Dim seen As Map
    seen.Initialize
    Dim q As String = partialQuery.ToLowerCase

    If q.Length < 2 Then Return suggestions

    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.Title.ToLowerCase.StartsWith(q) And seen.ContainsKey(evt.Title) = False Then
            suggestions.Add(evt.Title)
            seen.Put(evt.Title, True)
            If suggestions.Size >= 5 Then Return suggestions
        End If
    Next

    For i = 0 To mAllTasks.Size - 1
        Dim task As FamilyTask = mAllTasks.Get(i)
        If task.Title.ToLowerCase.StartsWith(q) And seen.ContainsKey(task.Title) = False Then
            suggestions.Add(task.Title)
            seen.Put(task.Title, True)
            If suggestions.Size >= 5 Then Return suggestions
        End If
    Next

    Return suggestions
End Sub
