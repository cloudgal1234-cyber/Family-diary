'=============================================================================
' RecurringEventManager.bas — ניהול אירועים חוזרים (חוגים שבועיים וכד')
' B4X Class Module
'
' תיאור: מרחיב אירועי Template לאירועים בודדים לכל שבוע.
'         תומך ב: DAILY / WEEKLY / MONTHLY.
'         כשמבטלים מופע בודד — נוצא "exception" לאותו תאריך בלבד.
'         כשמזיזים את כל הסדרה — כל המופעים הבאים מתעדכנים.
'=============================================================================
Sub Class_Globals

    Private mEventsCache   As Map   ' תבניות: templateId → CalendarEvent
    Private mExceptions    As Map   ' חריגים: templateId_dateStr → CalendarEvent
    Private mDtUtils       As DateTimeUtils
    Private mDbManager     As DatabaseManager

End Sub

Public Sub Initialize(dbManager As DatabaseManager)
    mDbManager = dbManager
    mDtUtils.Initialize
    mEventsCache.Initialize
    mExceptions.Initialize
End Sub

'-----------------------------------------------------------------------------
' רענון cache התבניות
'-----------------------------------------------------------------------------
Public Sub SetTemplates(events As List)
    mEventsCache.Initialize
    For i = 0 To events.Size - 1
        Dim evt As CalendarEvent = events.Get(i)
        If evt.IsRecurring Then
            mEventsCache.Put(evt.Id, evt)
        End If
    Next
End Sub

Public Sub SetException(exc As CalendarEvent)
    Dim key As String = exc.Id & "_" & exc.DateStr
    mExceptions.Put(key, exc)
End Sub

'-----------------------------------------------------------------------------
' קבל את כל המופעים לשבוע נתון
' מחזיר List של CalendarEvent (תבניות + מופעי חריג)
'-----------------------------------------------------------------------------
Public Sub GetOccurrencesForWeek(weekStartDate As String) As List
    Dim result As List
    result.Initialize

    Dim weekStartTs As Long = mDtUtils.DateStrToTs(weekStartDate)

    For i = 0 To mEventsCache.Size - 1
        Dim template As CalendarEvent = mEventsCache.GetValueAt(i)
        Dim occurrences As List = GetOccurrencesInRange(template, weekStartTs, weekStartTs + 7 * 86400000)

        For j = 0 To occurrences.Size - 1
            result.Add(occurrences.Get(j))
        Next
    Next

    Return result
End Sub

'-----------------------------------------------------------------------------
' קבל מופעים של תבנית בטווח תאריכים
'-----------------------------------------------------------------------------
Public Sub GetOccurrencesInRange(template As CalendarEvent, fromTs As Long, toTs As Long) As List
    Dim result As List
    result.Initialize

    If template.IsRecurring = False Then
        If template.CurrentStartTs >= fromTs And template.CurrentStartTs < toTs Then
            result.Add(template)
        End If
        Return result
    End If

    ' חשב את כל המועדים בטווח
    Dim candDates As List = CalcRecurrenceDates(template, fromTs, toTs)

    For i = 0 To candDates.Size - 1
        Dim occDateStr As String = candDates.Get(i)
        Dim occDateTs  As Long   = mDtUtils.DateStrToTs(occDateStr)

        ' חשב timestamps המדויקים לאותו יום
        Dim origMidnight As Long = mDtUtils.GetMidnight(template.OriginalStartTs)
        Dim timeOffset   As Long = template.OriginalStartTs - origMidnight
        Dim durMs        As Long = template.OriginalEndTs - template.OriginalStartTs

        Dim occStartTs As Long = occDateTs + timeOffset
        Dim occEndTs   As Long = occStartTs + durMs

        ' בדוק אם יש exception לתאריך זה
        Dim excKey As String = template.Id & "_" & occDateStr
        If mExceptions.ContainsKey(excKey) Then
            Dim exc As CalendarEvent = mExceptions.Get(excKey)
            If exc.IsDeleted = False Then result.Add(exc)
        Else
            ' מופע רגיל — שכפול התבנית עם תאריך חדש
            Dim occ As CalendarEvent = CloneForDate(template, occDateStr, occStartTs, occEndTs)
            result.Add(occ)
        End If
    Next

    Return result
End Sub

'-----------------------------------------------------------------------------
' חישוב תאריכי חזרה
'-----------------------------------------------------------------------------
Private Sub CalcRecurrenceDates(template As CalendarEvent, fromTs As Long, toTs As Long) As List
    Dim result As List
    result.Initialize

    Dim endDateTs As Long = 0
    If template.RecurrenceEndDate <> "" Then
        endDateTs = mDtUtils.DateStrToTs(template.RecurrenceEndDate)
    End If

    Select Case template.RecurrenceFreq

        Case "DAILY"
            Dim curTs As Long = mDtUtils.GetMidnight(fromTs)
            Do While curTs < toTs
                If endDateTs > 0 And curTs > endDateTs Then Exit
                result.Add(mDtUtils.TsToDateStr(curTs))
                curTs = curTs + 86400000
            Loop

        Case "WEEKLY"
            ' בדוק כל יום בשבוע שנמצא ב-RecurrenceDays
            Dim curTs As Long = mDtUtils.GetMidnight(fromTs)
            Do While curTs < toTs
                If endDateTs > 0 And curTs > endDateTs Then Exit
                Dim dayOfWeek As Int = GetDayOfWeek(curTs)   ' 0=ראשון, 1=שני...
                For d = 0 To template.RecurrenceDays.Size - 1
                    If CInt(template.RecurrenceDays.Get(d)) = dayOfWeek Then
                        result.Add(mDtUtils.TsToDateStr(curTs))
                        Exit For
                    End If
                Next
                curTs = curTs + 86400000
            Loop

        Case "MONTHLY"
            ' אותו יום בחודש
            Dim origDayOfMonth As Int = GetDayOfMonth(template.OriginalStartTs)
            Dim curTs As Long = mDtUtils.GetMidnight(fromTs)
            Do While curTs < toTs
                If endDateTs > 0 And curTs > endDateTs Then Exit
                If GetDayOfMonth(curTs) = origDayOfMonth Then
                    result.Add(mDtUtils.TsToDateStr(curTs))
                End If
                curTs = curTs + 86400000
            Loop

    End Select

    Return result
End Sub

'-----------------------------------------------------------------------------
' שכפול תבנית לתאריך ספציפי
'-----------------------------------------------------------------------------
Private Sub CloneForDate(template As CalendarEvent, dateStr As String, startTs As Long, endTs As Long) As CalendarEvent
    Dim occ As CalendarEvent
    occ.Initialize
    occ.Id              = template.Id & "_" & dateStr   ' מזהה ייחודי למופע
    occ.FamilyId        = template.FamilyId
    occ.Title           = template.Title
    occ.Description     = template.Description
    occ.Location        = template.Location
    occ.Category        = template.Category
    occ.ColorHex        = template.ColorHex
    occ.DateStr         = dateStr
    occ.OriginalStartTs = startTs
    occ.OriginalEndTs   = endTs
    occ.CurrentStartTs  = startTs
    occ.CurrentEndTs    = endTs
    occ.Status          = "ON_TIME"
    occ.CreatedBy       = template.CreatedBy
    occ.UpdatedBy       = template.UpdatedBy
    occ.CreatedAt       = template.CreatedAt
    occ.UpdatedAt       = template.UpdatedAt
    occ.IsRecurring     = False   ' המופע עצמו אינו חוזר
    occ.NotifyBeforeMinutes = template.NotifyBeforeMinutes
    occ.NotifyEnabled   = template.NotifyEnabled
    Return occ
End Sub

'-----------------------------------------------------------------------------
' ביטול מופע בודד — יוצר exception במסד הנתונים
'-----------------------------------------------------------------------------
Public Sub CancelOccurrence(templateId As String, dateStr As String, reason As String)
    ' קרא את התבנית מה-cache
    If mEventsCache.ContainsKey(templateId) = False Then Return
    Dim template As CalendarEvent = mEventsCache.Get(templateId)

    Dim occDateTs    As Long = mDtUtils.DateStrToTs(dateStr)
    Dim origMidnight As Long = mDtUtils.GetMidnight(template.OriginalStartTs)
    Dim timeOffset   As Long = template.OriginalStartTs - origMidnight
    Dim durMs        As Long = template.OriginalEndTs - template.OriginalStartTs
    Dim occStartTs   As Long = occDateTs + timeOffset

    Dim exc As CalendarEvent = CloneForDate(template, dateStr, occStartTs, occStartTs + durMs)
    exc.Id         = templateId & "_" & dateStr
    exc.Status     = "CANCELED"
    exc.StatusNote = reason

    mDbManager.SaveEvent(exc)
    SetException(exc)
End Sub

'-----------------------------------------------------------------------------
' הזזת מופע בודד
'-----------------------------------------------------------------------------
Public Sub MoveOccurrence(templateId As String, dateStr As String, _
                           newStartTs As Long, newEndTs As Long, note As String)
    If mEventsCache.ContainsKey(templateId) = False Then Return
    Dim template As CalendarEvent = mEventsCache.Get(templateId)

    Dim occDateTs    As Long = mDtUtils.DateStrToTs(dateStr)
    Dim origMidnight As Long = mDtUtils.GetMidnight(template.OriginalStartTs)
    Dim timeOffset   As Long = template.OriginalStartTs - origMidnight
    Dim durMs        As Long = template.OriginalEndTs - template.OriginalStartTs
    Dim occStartTs   As Long = occDateTs + timeOffset

    Dim exc As CalendarEvent = CloneForDate(template, dateStr, occStartTs, occStartTs + durMs)
    exc.Id              = templateId & "_" & dateStr
    exc.CurrentStartTs  = newStartTs
    exc.CurrentEndTs    = newEndTs
    exc.Status          = "MOVED"
    exc.StatusNote      = note

    mDbManager.SaveEvent(exc)
    SetException(exc)
End Sub

'-----------------------------------------------------------------------------
' עדכון כל הסדרה (כל המופעים מהיום ואילך)
'-----------------------------------------------------------------------------
Public Sub UpdateSeries(templateId As String, newTitle As String, newLocation As String)
    If mEventsCache.ContainsKey(templateId) = False Then Return
    Dim template As CalendarEvent = mEventsCache.Get(templateId)
    template.Title    = newTitle
    template.Location = newLocation
    mDbManager.SaveEvent(template)
End Sub

'-----------------------------------------------------------------------------
' עזרי תאריך
'-----------------------------------------------------------------------------
Private Sub GetDayOfWeek(ts As Long) As Int
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "u"   ' 1=Mon...7=Sun
    Dim dow As Int = CInt(DateTime.Date(ts))
    DateTime.DateFormat = old
    Return (dow Mod 7)   ' המרה ל-0=ראשון...6=שבת
End Sub

Private Sub GetDayOfMonth(ts As Long) As Int
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "d"
    Dim day As Int = CInt(DateTime.Date(ts))
    DateTime.DateFormat = old
    Return day
End Sub
