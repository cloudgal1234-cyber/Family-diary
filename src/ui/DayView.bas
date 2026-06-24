'=============================================================================
' DayView.bas — תצוגת יום מפורטת (Daily Timeline)
' B4X Class Module
'
' תיאור: תצוגת ציר זמן מפורטת ליום בודד.
'         - שעות מפורטות עם חצי שעה
'         - אירועים מוצגים כבלוקים רחבים עם כל הפרטים
'         - תצוגת "ציר סטטוס" — מה השתנה היום
'         - גלילה לשעה הנוכחית בפתיחה
'=============================================================================
Sub Class_Globals

    Private mPanel       As B4XView
    Private mEvtManager  As EventManager
    Private mConfig      As AppConfig
    Private mDtUtils     As DateTimeUtils
    Private mEventObject As String

    Private mDateLabel   As B4XView
    Private mScrollView  As ScrollView
    Private mTimelinePanel As B4XView
    Private mChangedPanel  As B4XView   ' פאנל "מה השתנה"

    Private mCurrentDate  As String
    Private CELL_H_DP     As Int = 80   ' גדול יותר מהתצוגה השבועית

End Sub

Public Sub Initialize(panel As B4XView, evtMgr As EventManager, _
                       config As AppConfig, eventObject As String)
    mPanel       = panel
    mEvtManager  = evtMgr
    mConfig      = config
    mEventObject = eventObject
    mDtUtils.Initialize
    BuildLayout
End Sub

Private Sub BuildLayout()
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim cellH   As Int   = CELL_H_DP * density
    Dim totalH  As Int   = cellH * 24

    ' כותרת תאריך
    mDateLabel = xui.CreateLabel("")
    mDateLabel.TextSize  = 16
    mDateLabel.TextStyle = Typeface.DEFAULT_BOLD
    mDateLabel.TextColor = 0xFF1A237E
    mDateLabel.Gravity   = Gravity.RIGHT Or Gravity.CENTER_VERTICAL
    mPanel.AddView(mDateLabel, 0, 0, mPanel.Width, 44 * density)

    ' פאנל "מה השתנה היום" (מוסתר כברירת מחדל)
    mChangedPanel = xui.CreatePanel("")
    mChangedPanel.Color   = 0xFFFFF8E1
    mChangedPanel.Visible = False
    mPanel.AddView(mChangedPanel, 0, 44 * density, mPanel.Width, 0)

    ' ScrollView
    mScrollView = xui.CreateScrollView(mPanel)
    mScrollView.SetLayoutAnimated(0, 0, 44 * density, mPanel.Width, mPanel.Height - 44 * density)
    mPanel.AddView(mScrollView, 0, 44 * density, mPanel.Width, mPanel.Height - 44 * density)

    mScrollView.Panel.SetSize(mPanel.Width, totalH)

    ' ציר הזמן
    mTimelinePanel = xui.CreatePanel("")
    mScrollView.Panel.AddView(mTimelinePanel, 0, 0, mPanel.Width, totalH)

    DrawTimeAxis(cellH, density)
End Sub

Private Sub DrawTimeAxis(cellH As Int, density As Float)
    Dim sideW As Int = 52 * density

    For h = 0 To 23
        Dim y As Int = h * cellH

        ' תווית שעה
        Dim timeLabel As B4XView = xui.CreateLabel(NumberFormat2(h, 2, 0, 0, False) & ":00")
        timeLabel.TextColor = 0xFF9E9E9E
        timeLabel.TextSize  = 12
        timeLabel.Gravity   = Gravity.RIGHT Or Gravity.TOP
        mTimelinePanel.AddView(timeLabel, 0, y + 4 * density, sideW - 8 * density, 18 * density)

        ' קו שעה
        Dim line As B4XView = xui.CreatePanel("")
        line.Color = 0xFFE0E0E0
        mTimelinePanel.AddView(line, sideW, y, mTimelinePanel.Width - sideW, 1)

        ' קו חצי שעה
        Dim halfLine As B4XView = xui.CreatePanel("")
        halfLine.Color = 0xFFF5F5F5
        mTimelinePanel.AddView(halfLine, sideW + 8 * density, y + cellH / 2, mTimelinePanel.Width - sideW - 8 * density, 1)
    Next
End Sub

Public Sub ShowDate(dateStr As String)
    mCurrentDate = dateStr
    Dim ts As Long = mDtUtils.DateStrToTs(dateStr)
    mDateLabel.Text = mDtUtils.FormatDateHebrew(ts)

    ClearEventBlocks
    DrawEvents(dateStr)
    ShowChangedEvents(dateStr)

    ' גלול לשעה הנוכחית
    If mDtUtils.IsToday(ts) Then
        Dim density As Float = GetDeviceLayoutValues.Scale
        Dim cellH   As Int   = CELL_H_DP * density
        Dim nowY    As Int   = TsToY(DateTime.Now, cellH)
        mScrollView.ScrollTo(0, Max(0, nowY - 100 * density))
    Else
        mScrollView.ScrollTo(0, CELL_H_DP * GetDeviceLayoutValues.Scale * 7)
    End If
End Sub

Private Sub DrawEvents(dateStr As String)
    Dim events  As List  = mEvtManager.GetEventsForDate(dateStr)
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim cellH   As Int   = CELL_H_DP * density
    Dim sideW   As Int   = 52 * density
    Dim blockW  As Int   = mPanel.Width - sideW - 8 * density

    For i = 0 To events.Size - 1
        Dim evt    As CalendarEvent = events.Get(i)
        Dim startY As Int = TsToY(evt.CurrentStartTs, cellH)
        Dim endY   As Int = TsToY(evt.CurrentEndTs, cellH)
        Dim blockH As Int = Max(endY - startY, 40 * density)

        ' --- בלוק ראשי ---
        Dim block As B4XView = xui.CreatePanel("")
        Dim colorInt As Int = ParseHexColor(evt.GetDisplayColor())
        block.Color   = ApplyAlpha(colorInt, 0xE8)
        block.Elevation = 2
        mTimelinePanel.AddView(block, sideW, startY + 1, blockW, blockH - 2)

        ' פס שמאלי
        Dim leftBar As B4XView = xui.CreatePanel("")
        leftBar.Color = ApplyAlpha(colorInt, 0xFF)
        block.AddView(leftBar, 0, 0, 5 * density, blockH - 2)

        ' כותרת
        Dim titleLbl As B4XView = xui.CreateLabel(evt.Title)
        titleLbl.TextStyle = Typeface.DEFAULT_BOLD
        titleLbl.TextSize  = 14
        titleLbl.TextColor = 0xFF212121
        block.AddView(titleLbl, 10 * density, 6 * density, blockW - 20 * density, 22 * density)

        ' שעה
        Dim timeLbl As B4XView = xui.CreateLabel(mDtUtils.FormatTimeRange(evt.CurrentStartTs, evt.CurrentEndTs))
        timeLbl.TextSize  = 12
        timeLbl.TextColor = 0xFF424242
        block.AddView(timeLbl, 10 * density, 28 * density, blockW - 80 * density, 18 * density)

        ' תגית סטטוס Hot Update
        If evt.Status <> "ON_TIME" Then
            Dim statusBadge As B4XView = xui.CreateLabel(mConfig.GetStatusName(evt.Status))
            statusBadge.TextSize  = 10
            statusBadge.TextColor = 0xFFFFFFFF
            statusBadge.Color     = ParseHexColor(mConfig.GetStatusColor(evt.Status))
            statusBadge.Gravity   = Gravity.CENTER
            statusBadge.Padding   = Array As Int(4, 2, 4, 2)
            block.AddView(statusBadge, blockW - 60 * density, 6 * density, 56 * density, 20 * density)

            ' הצגת זמן מקורי (אם הוזז)
            If evt.WasMoved Then
                Dim origLbl As B4XView = xui.CreateLabel("מקורי: " & mDtUtils.FormatTime(evt.OriginalStartTs))
                origLbl.TextSize  = 10
                origLbl.TextColor = 0xFF757575
                origLbl.TextStyle = Typeface.DEFAULT ' strikethrough ב-real code
                block.AddView(origLbl, 10 * density, 48 * density, 120 * density, 16 * density)
            End If
        End If

        ' מיקום
        If evt.Location <> "" And blockH > 60 * density Then
            Dim locLbl As B4XView = xui.CreateLabel("📍 " & evt.Location)
            locLbl.TextSize  = 11
            locLbl.TextColor = 0xFF616161
            block.AddView(locLbl, 10 * density, blockH - 22 * density, blockW - 16 * density, 16 * density)
        End If

        block.Tag = evt.Id
        block.AddEventListener("Click", mEventObject, "DayEventBlock_Click")
    Next
End Sub

Private Sub ShowChangedEvents(dateStr As String)
    Dim changed As List = mEvtManager.GetChangedEvents
    Dim todayChanged As List
    todayChanged.Initialize

    For i = 0 To changed.Size - 1
        Dim evt As CalendarEvent = changed.Get(i)
        If evt.DateStr = dateStr Then todayChanged.Add(evt)
    Next

    If todayChanged.Size = 0 Then
        mChangedPanel.Visible = False
        mScrollView.SetLayoutAnimated(0, 0, 44 * GetDeviceLayoutValues.Scale, _
            mPanel.Width, mPanel.Height - 44 * GetDeviceLayoutValues.Scale)
        Return
    End If

    ' הצג פאנל "מה השתנה"
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim panelH  As Int   = (14 + todayChanged.Size * 22) * density

    mChangedPanel.Visible = True
    mChangedPanel.SetLayoutAnimated(0, 0, 44 * density, mPanel.Width, panelH)

    ' כותרת
    Dim hdrLbl As B4XView = xui.CreateLabel("⚡ שינויים להיום:")
    hdrLbl.TextSize  = 12
    hdrLbl.TextStyle = Typeface.DEFAULT_BOLD
    hdrLbl.TextColor = 0xFFF57F17
    mChangedPanel.AddView(hdrLbl, 8 * density, 4 * density, mPanel.Width - 16 * density, 18 * density)

    For i = 0 To todayChanged.Size - 1
        Dim evt    As CalendarEvent = todayChanged.Get(i)
        Dim rowLbl As B4XView = xui.CreateLabel("• " & evt.Title & " — " & evt.GetStatusLabel)
        rowLbl.TextSize  = 11
        rowLbl.TextColor = 0xFF5D4037
        mChangedPanel.AddView(rowLbl, 12 * density, (22 + i * 22) * density, mPanel.Width - 24 * density, 18 * density)
    Next

    mScrollView.SetLayoutAnimated(0, 0, (44 + panelH) * density, mPanel.Width, mPanel.Height - (44 + panelH) * density)
End Sub

Private Sub ClearEventBlocks()
    ' מחק רק בלוקי אירועים (לא ציר הזמן)
    ' ב-B4X: חזור על כל הילדים וזהה לפי Tag
    For i = mTimelinePanel.NumberOfViews - 1 To 0 Step -1
        Dim v As B4XView = mTimelinePanel.GetView(i)
        If v.Tag <> "" Then v.RemoveView
    Next
End Sub

Sub DayEventBlock_Click(view As B4XView)
    RaiseEvent(mEventObject, "DayEventSelected", Array(view.Tag))
End Sub

Private Sub TsToY(ts As Long, cellH As Int) As Int
    Dim midnight As Long = mDtUtils.GetMidnight(ts)
    Return CInt((ts - midnight) * cellH / 3600000)
End Sub

Private Sub Max(a As Int, b As Int) As Int
    If a > b Then Return a
    Return b
End Sub

Private Sub ParseHexColor(hex As String) As Int
    If hex.StartsWith("#") Then
        Return Bit.ParseInt("FF" & hex.SubString(1), 16)
    End If
    Return 0xFF9E9E9E
End Sub

Private Sub ApplyAlpha(color As Int, alpha As Int) As Int
    Return Bit.Or(Bit.ShiftLeft(alpha, 24), Bit.And(color, 0x00FFFFFF))
End Sub
