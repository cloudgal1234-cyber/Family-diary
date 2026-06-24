'=============================================================================
' CalendarWeekView.bas — תצוגת לוח שנה שבועית (Visual Weekly Grid)
' B4X Class Module
'
' תיאור: מציגה רשת 7 ימים × 24 שעות.
'         כל אירוע מוצג כבלוק צבעוני.
'         אירועים שהוזזו מקבלים תגית Hot Update אדומה/כתומה.
'         תמיכה מלאה ב-RTL (עברית).
'
' תלויות: CalendarEvent, EventManager, DateTimeUtils, AppConfig
'         B4XViews (XUI Library)
'
' שימוש:
'   Dim weekView As CalendarWeekView
'   weekView.Initialize(Panel1, EventManager1, Config1, "WeekView")
'   weekView.ShowWeek("2024-11-11")   ' יום שני של השבוע הרצוי
'=============================================================================
Sub Class_Globals

    Private mParentPanel  As B4XView
    Private mEvtManager   As EventManager
    Private mConfig       As AppConfig
    Private mDtUtils      As DateTimeUtils
    Private mEventObject  As String

    ' תאי הרשת
    Private mHeaderRow    As B4XView   ' שורת ימים בראש
    Private mScrollView   As ScrollView
    Private mGridPanel    As B4XView   ' לוח הרשת הראשי
    Private mSidebarPanel As B4XView   ' עמודת שעות

    ' מצב
    Private mCurrentWeekStart As String   ' "2024-11-11"
    Private mSelectedDate     As String
    Private mEventBlocks      As Map      ' eventId → B4XView (לעדכון מהיר)

    ' ממדים (מחושבים בזמן ריצה)
    Private mCellH   As Int   ' גובה שעה בפיקסלים
    Private mDayW    As Int   ' רוחב יום בפיקסלים
    Private mSideW   As Int   ' רוחב עמודת שעות

    ' צבעים
    Private COLOR_GRID_LINE    As Int = 0xFFE0E0E0
    Private COLOR_TODAY_BG     As Int = 0xFFFFF9C4
    Private COLOR_HEADER_BG    As Int = 0xFF1A237E
    Private COLOR_HEADER_TEXT  As Int = 0xFFFFFFFF
    Private COLOR_HOUR_TEXT    As Int = 0xFF757575
    Private COLOR_MOVED_BADGE  As Int = 0xFFF39C12
    Private COLOR_CANCEL_BADGE As Int = 0xFFE74C3C

End Sub

'-----------------------------------------------------------------------------
' אתחול
'-----------------------------------------------------------------------------
Public Sub Initialize(parentPanel As B4XView, evtMgr As EventManager, _
                       config As AppConfig, eventObject As String)
    mParentPanel = parentPanel
    mEvtManager  = evtMgr
    mConfig      = config
    mEventObject = eventObject
    mDtUtils.Initialize
    mEventBlocks.Initialize

    mCellH = config.CELL_HEIGHT_DP * GetDeviceDensity()
    mSideW = config.SIDEBAR_WIDTH_DP * GetDeviceDensity()
    mDayW  = (mParentPanel.Width - mSideW) / 7

    BuildLayout
End Sub

'-----------------------------------------------------------------------------
' בנייה ראשונית של הלייאאוט
'-----------------------------------------------------------------------------
Private Sub BuildLayout()
    ' כותרת ימים
    mHeaderRow = xui.CreatePanel("")
    mHeaderRow.SetLayoutAnimated(0, 0, 0, mParentPanel.Width, mConfig.WEEK_HEADER_HEIGHT_DP * GetDeviceDensity())
    mHeaderRow.Color = COLOR_HEADER_BG
    mParentPanel.AddView(mHeaderRow, 0, 0, mParentPanel.Width, mConfig.WEEK_HEADER_HEIGHT_DP * GetDeviceDensity())

    ' פינת עמודת שעות (ריקה)
    Dim cornerView As B4XView = xui.CreateLabel("")
    mHeaderRow.AddView(cornerView, 0, 0, mSideW, mHeaderRow.Height)

    ' כותרות ימים
    Dim dayNames() As String = Array As String("ש", "א", "ב", "ג", "ד", "ה", "ו")
    For i = 0 To 6
        Dim dayLabel As B4XView = xui.CreateLabel(dayNames(i))
        dayLabel.TextColor = COLOR_HEADER_TEXT
        dayLabel.TextSize  = 14
        dayLabel.Gravity   = Gravity.CENTER
        mHeaderRow.AddView(dayLabel, mSideW + i * mDayW, 0, mDayW, mHeaderRow.Height)
    Next

    ' ScrollView לרשת השעות
    mScrollView = xui.CreateScrollView(mParentPanel)
    mScrollView.SetLayoutAnimated(0, 0, mHeaderRow.Height, _
        mParentPanel.Width, mParentPanel.Height - mHeaderRow.Height)
    mParentPanel.AddView(mScrollView, 0, mHeaderRow.Height, _
        mParentPanel.Width, mParentPanel.Height - mHeaderRow.Height)

    Dim totalH As Int = mCellH * 24
    mScrollView.Panel.SetSize(mParentPanel.Width, totalH)

    ' עמודת שעות
    mSidebarPanel = xui.CreatePanel("")
    mSidebarPanel.Color = 0xFFFAFAFA
    mScrollView.Panel.AddView(mSidebarPanel, 0, 0, mSideW, totalH)
    DrawHourLabels

    ' לוח ראשי
    mGridPanel = xui.CreatePanel("")
    mScrollView.Panel.AddView(mGridPanel, mSideW, 0, mParentPanel.Width - mSideW, totalH)
    DrawGridLines

    ' גלול ל-7:00 (שעת ברירת מחדל)
    mScrollView.ScrollTo(0, mCellH * 7)
End Sub

'-----------------------------------------------------------------------------
' ציור תוויות שעות (00:00 עד 23:00)
'-----------------------------------------------------------------------------
Private Sub DrawHourLabels()
    For h = 0 To 23
        Dim label As B4XView = xui.CreateLabel(NumberFormat2(h, 2, 0, 0, False) & ":00")
        label.TextColor = COLOR_HOUR_TEXT
        label.TextSize  = 11
        label.Gravity   = Gravity.RIGHT Or Gravity.TOP
        mSidebarPanel.AddView(label, 0, h * mCellH - 8, mSideW - 4, 20)
    Next
End Sub

'-----------------------------------------------------------------------------
' ציור קווי רשת
'-----------------------------------------------------------------------------
Private Sub DrawGridLines()
    Dim totalH As Int = mCellH * 24
    Dim totalW As Int = mDayW * 7

    ' קווים אופקיים — כל שעה
    For h = 0 To 23
        Dim line As B4XView = xui.CreatePanel("")
        line.Color = COLOR_GRID_LINE
        mGridPanel.AddView(line, 0, h * mCellH, totalW, 1)

        ' קו מקווקו לחצי שעה
        Dim halfLine As B4XView = xui.CreatePanel("")
        halfLine.Color = 0xFFEEEEEE
        mGridPanel.AddView(halfLine, 0, h * mCellH + mCellH / 2, totalW, 1)
    Next

    ' קווים אנכיים — כל יום
    For d = 0 To 6
        Dim vLine As B4XView = xui.CreatePanel("")
        vLine.Color = COLOR_GRID_LINE
        mGridPanel.AddView(vLine, d * mDayW, 0, 1, totalH)
    Next
End Sub

'-----------------------------------------------------------------------------
' הצגת שבוע — הפונקציה הראשית
'-----------------------------------------------------------------------------
Public Sub ShowWeek(weekStartDate As String)
    mCurrentWeekStart = weekStartDate
    UpdateDayHeaders(weekStartDate)
    ClearEventBlocks
    DrawEventsForWeek(weekStartDate)
    HighlightToday(weekStartDate)
End Sub

' עדכון כותרות ימים עם תאריכים
Private Sub UpdateDayHeaders(weekStart As String)
    Dim startTs As Long = mDtUtils.DateStrToTs(weekStart)
    Dim dayNames() As String = Array As String("שבת", "ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי")

    ' מחיקת כותרות ישנות (מלבד הפינה)
    Do While mHeaderRow.NumberOfViews > 1
        mHeaderRow.RemoveViewAt(mHeaderRow.NumberOfViews - 1)
    Loop

    For i = 0 To 6
        Dim dayTs  As Long   = startTs + (i * 86400000)
        Dim dayNum As String = mDtUtils.TsToDateStr(dayTs).SubString(8)   ' DD

        Dim dayPanel As B4XView = xui.CreatePanel("")
        mHeaderRow.AddView(dayPanel, mSideW + i * mDayW, 0, mDayW, mHeaderRow.Height)

        Dim nameLabel As B4XView = xui.CreateLabel(dayNames(i))
        nameLabel.TextColor = 0xFFB0BEC5
        nameLabel.TextSize  = 10
        nameLabel.Gravity   = Gravity.CENTER_HORIZONTAL Or Gravity.BOTTOM
        dayPanel.AddView(nameLabel, 0, 2, mDayW, mHeaderRow.Height / 2)

        Dim numLabel As B4XView = xui.CreateLabel(dayNum)
        numLabel.TextColor = COLOR_HEADER_TEXT
        numLabel.TextSize  = 18
        numLabel.TextStyle = Typeface.DEFAULT_BOLD
        numLabel.Gravity   = Gravity.CENTER
        dayPanel.AddView(numLabel, 0, mHeaderRow.Height / 2 - 4, mDayW, mHeaderRow.Height / 2)
    Next
End Sub

'-----------------------------------------------------------------------------
' ציור בלוקי אירועים לכל השבוע
'-----------------------------------------------------------------------------
Private Sub DrawEventsForWeek(weekStart As String)
    Dim startTs As Long = mDtUtils.DateStrToTs(weekStart)

    For dayIdx = 0 To 6
        Dim dayTs  As Long   = startTs + (dayIdx * 86400000)
        Dim dayStr As String = mDtUtils.TsToDateStr(dayTs)
        Dim events As List   = mEvtManager.GetEventsForDate(dayStr)

        Dim dayX As Int = dayIdx * mDayW + 2   ' +2 מרווח מקו הרשת

        For i = 0 To events.Size - 1
            Dim evt As CalendarEvent = events.Get(i)
            DrawEventBlock(evt, dayX)
        Next
    Next
End Sub

'-----------------------------------------------------------------------------
' ציור בלוק אירוע בודד
'-----------------------------------------------------------------------------
Private Sub DrawEventBlock(evt As CalendarEvent, dayX As Int)
    ' חישוב מיקום ב-Y לפי שעה
    Dim startY As Int = TsToYPixel(evt.CurrentStartTs)
    Dim endY   As Int = TsToYPixel(evt.CurrentEndTs)
    Dim blockH As Int = Max(endY - startY, mConfig.EVENT_BLOCK_MIN_HEIGHT)

    ' צבע הקטגוריה (עם שקיפות קלה)
    Dim colorHex As String = evt.GetDisplayColor()
    Dim blockColor As Int  = ParseColorWithAlpha(colorHex, 0xE0)

    ' הפאנל הראשי של הבלוק
    Dim block As B4XView = xui.CreatePanel("")
    block.Color = blockColor
    block.Tag   = evt.Id
    SetRoundedCorners(block, 6)
    mGridPanel.AddView(block, dayX, startY, mDayW - 4, blockH)

    ' אייקון סטטוס (Hot Update)
    If evt.Status <> "ON_TIME" Then
        DrawStatusBadge(block, evt)
    End If

    ' כותרת האירוע
    Dim titleLabel As B4XView = xui.CreateLabel(evt.Title)
    titleLabel.TextColor = 0xFFFFFFFF
    titleLabel.TextSize  = 10
    titleLabel.TextStyle = Typeface.DEFAULT_BOLD
    titleLabel.SingleLine = True
    block.AddView(titleLabel, 4, 2, block.Width - 8, 16)

    ' שעה
    If blockH > 30 Then
        Dim timeLabel As B4XView = xui.CreateLabel(mDtUtils.FormatTimeRange(evt.CurrentStartTs, evt.CurrentEndTs))
        timeLabel.TextColor = 0xDDFFFFFF
        timeLabel.TextSize  = 9
        block.AddView(timeLabel, 4, 16, block.Width - 8, 14)
    End If

    ' לחיצה → פרטי אירוע
    block.AddEventListener("Click", mEventObject, "EventBlock_Click")

    mEventBlocks.Put(evt.Id, block)
End Sub

'-----------------------------------------------------------------------------
' תגית Hot Update (MOVED / CANCELED)
'-----------------------------------------------------------------------------
Private Sub DrawStatusBadge(block As B4XView, evt As CalendarEvent)
    Dim badgeColor As Int
    Dim badgeText  As String

    Select Case evt.Status
        Case "CANCELED"
            badgeColor = COLOR_CANCEL_BADGE
            badgeText  = "✕"
        Case "MOVED", "RESCHEDULED"
            badgeColor = COLOR_MOVED_BADGE
            badgeText  = "!"
        Case "POSTPONED"
            badgeColor = 0xFF9B59B6
            badgeText  = "→"
        Case Else
            Return
    End Select

    Dim badge As B4XView = xui.CreateLabel(badgeText)
    badge.TextColor = 0xFFFFFFFF
    badge.TextSize  = 9
    badge.TextStyle = Typeface.DEFAULT_BOLD
    badge.Color     = badgeColor
    badge.Gravity   = Gravity.CENTER
    SetRoundedCorners(badge, 8)
    block.AddView(badge, block.Width - 16, 2, 14, 14)

    ' פס אנכי לצד שמאל (צבע הסטטוס)
    Dim stripe As B4XView = xui.CreatePanel("")
    stripe.Color = badgeColor
    block.AddView(stripe, 0, 0, 3, block.Height)
End Sub

'-----------------------------------------------------------------------------
' עדכון בלוק בודד בזמן אמת (ללא רענון מלא)
'-----------------------------------------------------------------------------
Public Sub RefreshEventBlock(evt As CalendarEvent)
    If mEventBlocks.ContainsKey(evt.Id) Then
        Dim oldBlock As B4XView = mEventBlocks.Get(evt.Id)
        Dim parent   As B4XView = oldBlock.Parent

        ' מחק את הבלוק הישן
        oldBlock.RemoveView

        ' ציור מחדש באותו X
        Dim dayIdx As Int = GetDayIndexForDate(evt.DateStr)
        If dayIdx >= 0 Then
            DrawEventBlock(evt, dayIdx * mDayW + 2)
        End If
    End If
End Sub

'-----------------------------------------------------------------------------
' הדגשת היום הנוכחי
'-----------------------------------------------------------------------------
Private Sub HighlightToday(weekStart As String)
    Dim todayStr   As String = mDtUtils.TsToDateStr(DateTime.Now)
    Dim startTs    As Long   = mDtUtils.DateStrToTs(weekStart)

    For i = 0 To 6
        Dim dayStr As String = mDtUtils.TsToDateStr(startTs + i * 86400000)
        If dayStr = todayStr Then
            Dim todayBg As B4XView = xui.CreatePanel("")
            todayBg.Color = COLOR_TODAY_BG
            ' הוסף מאחורי הכל (index 0)
            mGridPanel.AddView(todayBg, i * mDayW, 0, mDayW, mCellH * 24)
            mGridPanel.SendToBack(todayBg)

            ' קו "עכשיו" אדום
            DrawCurrentTimeLine(i)
            Return
        End If
    Next
End Sub

' קו אופקי אדום = השעה הנוכחית
Private Sub DrawCurrentTimeLine(dayIdx As Int)
    Dim nowY As Int = TsToYPixel(DateTime.Now)
    Dim line As B4XView = xui.CreatePanel("")
    line.Color = 0xFFE53935
    mGridPanel.AddView(line, dayIdx * mDayW, nowY - 1, mDayW, 2)

    ' עיגול קטן בצד שמאל
    Dim dot As B4XView = xui.CreatePanel("")
    dot.Color = 0xFFE53935
    SetRoundedCorners(dot, 5)
    mGridPanel.AddView(dot, dayIdx * mDayW - 4, nowY - 5, 10, 10)
End Sub

'-----------------------------------------------------------------------------
' ניווט שבועות
'-----------------------------------------------------------------------------
Public Sub GoToNextWeek()
    Dim nextStart As Long = mDtUtils.DateStrToTs(mCurrentWeekStart) + (7 * 86400000)
    ShowWeek(mDtUtils.TsToDateStr(nextStart))
End Sub

Public Sub GoToPrevWeek()
    Dim prevStart As Long = mDtUtils.DateStrToTs(mCurrentWeekStart) - (7 * 86400000)
    ShowWeek(mDtUtils.TsToDateStr(prevStart))
End Sub

Public Sub GoToCurrentWeek()
    ShowWeek(GetCurrentWeekMonday())
End Sub

Private Sub GetCurrentWeekMonday() As String
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "u"
    Dim dow As Int = CInt(DateTime.Date(DateTime.Now))   ' 1=Mon
    DateTime.DateFormat = old
    Dim mondayTs As Long = mDtUtils.GetMidnight(DateTime.Now) - ((dow - 1) * 86400000)
    Return mDtUtils.TsToDateStr(mondayTs)
End Sub

'-----------------------------------------------------------------------------
' עזרים פנימיים
'-----------------------------------------------------------------------------

' Timestamp → Y pixel בלוח השעות
Private Sub TsToYPixel(ts As Long) As Int
    Dim midnight As Long = mDtUtils.GetMidnight(ts)
    Dim msFromMidnight As Long = ts - midnight
    Return CInt(msFromMidnight * mCellH / 3600000)
End Sub

Private Sub ClearEventBlocks()
    For i = 0 To mEventBlocks.Size - 1
        Dim block As B4XView = mEventBlocks.GetValueAt(i)
        block.RemoveView
    Next
    mEventBlocks.Initialize
End Sub

Private Sub GetDayIndexForDate(dateStr As String) As Int
    Dim startTs As Long = mDtUtils.DateStrToTs(mCurrentWeekStart)
    For i = 0 To 6
        If mDtUtils.TsToDateStr(startTs + i * 86400000) = dateStr Then Return i
    Next
    Return -1
End Sub

Private Sub ParseColorWithAlpha(hex As String, alpha As Int) As Int
    Dim r As Int = Bit.ParseInt(hex.SubString2(1, 3), 16)
    Dim g As Int = Bit.ParseInt(hex.SubString2(3, 5), 16)
    Dim b As Int = Bit.ParseInt(hex.SubString2(5, 7), 16)
    Return Bit.Or(Bit.ShiftLeft(alpha, 24), Bit.Or(Bit.ShiftLeft(r, 16), Bit.Or(Bit.ShiftLeft(g, 8), b)))
End Sub

Private Sub SetRoundedCorners(v As B4XView, radius As Int)
    Dim cd As B4XCanvasDrawer
    cd.Initialize(v)
    cd.DrawRoundRect(0, 0, v.Width, v.Height, radius, radius, True, xui.Color_Transparent, 0)
End Sub

Private Sub GetDeviceDensity() As Float
    Return GetDeviceLayoutValues.Scale
End Sub

Private Sub Max(a As Int, b As Int) As Int
    If a > b Then Return a
    Return b
End Sub

' אירוע לחיצה על בלוק — מועבר לאקטיביטי
Sub EventBlock_Click(view As B4XView)
    Dim eventId As String = view.Tag
    RaiseEvent(mEventObject, "EventSelected", Array(eventId))
End Sub

Public Sub GetCurrentWeekStart() As String
    Return mCurrentWeekStart
End Sub
