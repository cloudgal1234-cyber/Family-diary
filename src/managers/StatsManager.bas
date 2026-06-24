'=============================================================================
' StatsManager.bas — סטטיסטיקות שבועיות ותובנות
' B4X Class Module
'
' תיאור: מנתח את נתוני השבוע ומייצר:
'         - כמה שינויים היו השבוע
'         - קטגוריה עמוסה ביותר
'         - כמה שיעורי בית הושלמו
'         - "כרטיס תובנה" לתצוגה ב-UI
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
' סטטיסטיקות שבועיות מלאות
' מחזיר Map עשיר לשימוש ה-UI
'-----------------------------------------------------------------------------
Public Sub GetWeeklyStats(weekStartDate As String) As Map
    Dim stats As Map
    stats.Initialize

    Dim startTs  As Long = mDtUtils.DateStrToTs(weekStartDate)
    Dim endTs    As Long = startTs + 7 * 86400000

    ' --- אירועים ---
    Dim totalEvents    As Int = 0
    Dim movedEvents    As Int = 0
    Dim canceledEvents As Int = 0
    Dim onTimeEvents   As Int = 0
    Dim catCount       As Map
    catCount.Initialize

    For i = 0 To mAllEvents.Size - 1
        Dim evt As CalendarEvent = mAllEvents.Get(i)
        If evt.CurrentStartTs >= startTs And evt.CurrentStartTs < endTs Then
            totalEvents = totalEvents + 1
            Select Case evt.Status
                Case "MOVED", "RESCHEDULED" : movedEvents    = movedEvents + 1
                Case "CANCELED"             : canceledEvents = canceledEvents + 1
                Case Else                   : onTimeEvents   = onTimeEvents  + 1
            End Select

            Dim prevCount As Int = 0
            If catCount.ContainsKey(evt.Category) Then prevCount = catCount.Get(evt.Category)
            catCount.Put(evt.Category, prevCount + 1)
        End If
    Next

    ' --- משימות ---
    Dim totalTasks    As Int = 0
    Dim doneTasks     As Int = 0
    Dim overdueTasks  As Int = 0
    Dim urgentPending As Int = 0

    For i = 0 To mAllTasks.Size - 1
        Dim task As FamilyTask = mAllTasks.Get(i)
        If task.DueTs >= startTs And task.DueTs < endTs Then
            totalTasks = totalTasks + 1
            If task.IsDone          Then doneTasks     = doneTasks + 1
            If task.IsOverdue       Then overdueTasks  = overdueTasks + 1
            If task.Priority = "URGENT" And task.IsDone = False Then
                urgentPending = urgentPending + 1
            End If
        End If
    Next

    ' --- אחוז השלמה ---
    Dim completionPct As Int = 0
    If totalTasks > 0 Then completionPct = CInt(doneTasks * 100 / totalTasks)

    Dim changeRate As Int = 0
    If totalEvents > 0 Then changeRate = CInt((movedEvents + canceledEvents) * 100 / totalEvents)

    ' --- קטגוריה עמוסה ביותר ---
    Dim busyCat      As String = FindMaxCategory(catCount)

    stats.Put("week_start",       weekStartDate)
    stats.Put("total_events",     totalEvents)
    stats.Put("moved_events",     movedEvents)
    stats.Put("canceled_events",  canceledEvents)
    stats.Put("on_time_events",   onTimeEvents)
    stats.Put("change_rate_pct",  changeRate)
    stats.Put("category_counts",  catCount)
    stats.Put("busiest_category", busyCat)
    stats.Put("total_tasks",      totalTasks)
    stats.Put("done_tasks",       doneTasks)
    stats.Put("overdue_tasks",    overdueTasks)
    stats.Put("urgent_pending",   urgentPending)
    stats.Put("completion_pct",   completionPct)
    stats.Put("insight_cards",    BuildInsightCards(stats))

    Return stats
End Sub

'-----------------------------------------------------------------------------
' כרטיסי תובנה — משפטים קצרים לתצוגה ב-UI
'-----------------------------------------------------------------------------
Private Sub BuildInsightCards(stats As Map) As List
    Dim cards As List
    cards.Initialize

    Dim changeRate    As Int = stats.Get("change_rate_pct")
    Dim completionPct As Int = stats.Get("completion_pct")
    Dim urgentPending As Int = stats.Get("urgent_pending")
    Dim overdue       As Int = stats.Get("overdue_tasks")
    Dim busyCat       As String = stats.Get("busiest_category")

    ' כרטיס שינויים
    If changeRate > 50 Then
        AddCard(cards, "⚠️", "שבוע עמוס בשינויים", changeRate & "% מהאירועים השתנו — כדאי לבדוק!", "WARNING")
    Else If changeRate = 0 Then
        AddCard(cards, "✅", "שבוע יציב!", "כל האירועים רצו כמתוכנן", "SUCCESS")
    Else
        AddCard(cards, "📊", "רמת שינויים נמוכה", "רק " & changeRate & "% השתנו השבוע", "INFO")
    End If

    ' כרטיס שיעורי בית
    If completionPct = 100 Then
        AddCard(cards, "🏆", "כל שיעורי הבית הושלמו!", "עבודה מצוינת!", "SUCCESS")
    Else If completionPct >= 75 Then
        AddCard(cards, "📚", "כמעט שם!", completionPct & "% מהמשימות הושלמו", "INFO")
    Else If overdue > 0 Then
        AddCard(cards, "🔴", overdue & " משימות פגו תוקף", "יש לטפל בהן בהקדם", "WARNING")
    End If

    ' כרטיס דחוף
    If urgentPending > 0 Then
        AddCard(cards, "🔥", urgentPending & " משימות דחופות", "ממתינות לטיפול", "URGENT")
    End If

    ' קטגוריה עמוסה
    If busyCat <> "" Then
        AddCard(cards, "📅", "קטגוריה עמוסה: " & TranslateCategory(busyCat), "", "INFO")
    End If

    Return cards
End Sub

Private Sub AddCard(cards As List, icon As String, title As String, body As String, cardType As String)
    Dim card As Map
    card.Initialize
    card.Put("icon",  icon)
    card.Put("title", title)
    card.Put("body",  body)
    card.Put("type",  cardType)
    cards.Add(card)
End Sub

'-----------------------------------------------------------------------------
' סטטיסטיקות לכל הזמנים (All-time)
'-----------------------------------------------------------------------------
Public Sub GetAllTimeStats() As Map
    Dim stats As Map
    stats.Initialize

    Dim totalEvents  As Int = mAllEvents.Size
    Dim totalTasks   As Int = mAllTasks.Size
    Dim totalDone    As Int = 0
    Dim totalMoved   As Int = 0

    For i = 0 To mAllTasks.Size - 1
        Dim t As FamilyTask = mAllTasks.Get(i)
        If t.IsDone Then totalDone = totalDone + 1
    Next

    For i = 0 To mAllEvents.Size - 1
        Dim e As CalendarEvent = mAllEvents.Get(i)
        If e.WasMoved Or e.Status = "CANCELED" Then totalMoved = totalMoved + 1
    Next

    stats.Put("total_events",  totalEvents)
    stats.Put("total_tasks",   totalTasks)
    stats.Put("total_done",    totalDone)
    stats.Put("total_changed", totalMoved)

    Return stats
End Sub

'-----------------------------------------------------------------------------
' קטגוריה עם הכי הרבה אירועים
'-----------------------------------------------------------------------------
Private Sub FindMaxCategory(catCount As Map) As String
    Dim maxCat   As String = ""
    Dim maxCount As Int    = 0

    For i = 0 To catCount.Size - 1
        Dim cnt As Int = catCount.GetValueAt(i)
        If cnt > maxCount Then
            maxCount = cnt
            maxCat   = catCount.GetKeyAt(i)
        End If
    Next

    Return maxCat
End Sub

Private Sub TranslateCategory(cat As String) As String
    Select Case cat
        Case "CHUGIM"   : Return "חוגים"
        Case "HOMEWORK" : Return "שיעורי בית"
        Case "FAMILY"   : Return "משפחה"
        Case "FRIENDS"  : Return "חברים"
        Case Else       : Return cat
    End Select
End Sub
