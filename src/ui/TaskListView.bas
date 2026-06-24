'=============================================================================
' TaskListView.bas — תצוגת רשימת משימות ושיעורי בית
' B4X Class Module
'
' תיאור: רשימה מסוננת + ממוינת של FamilyTask.
'         - Checkbox להשלמה מהירה (עם אנימציית ✓)
'         - צבע עדיפות בפס שמאלי
'         - תגית Time-Block (מוצגת שעת עשיית המשימה)
'         - פילטרים: הכל / היום / מחר / דחוף
'         - Swipe-to-delete
'
' תלויות: FamilyTask, DatabaseManager, DateTimeUtils, AppConfig
'=============================================================================
Sub Class_Globals

    Private mPanel       As B4XView
    Private mDbManager   As DatabaseManager
    Private mDtUtils     As DateTimeUtils
    Private mConfig      As AppConfig
    Private mEventObject As String

    Private mListView    As B4XListView   ' הרשימה הראשית
    Private mFilterBar   As B4XView       ' שורת פילטרים
    Private mEmptyView   As B4XView       ' "אין משימות" placeholder

    Private mAllTasks    As List   ' כל המשימות הלא-מסוננות
    Private mFilter      As String = "ALL"   ' ALL / TODAY / TOMORROW / URGENT / DONE

    ' תאים פעילים: taskId → checkboxView (לעדכון מיידי)
    Private mCheckBoxMap As Map

End Sub

'-----------------------------------------------------------------------------
' אתחול
'-----------------------------------------------------------------------------
Public Sub Initialize(panel As B4XView, dbMgr As DatabaseManager, _
                       config As AppConfig, eventObject As String)
    mPanel       = panel
    mDbManager   = dbMgr
    mConfig      = config
    mEventObject = eventObject
    mDtUtils.Initialize
    mAllTasks.Initialize
    mCheckBoxMap.Initialize

    BuildLayout
End Sub

'-----------------------------------------------------------------------------
' בנייה ראשונית
'-----------------------------------------------------------------------------
Private Sub BuildLayout()
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim filterH As Int   = 48 * density

    ' --- שורת פילטרים ---
    mFilterBar = xui.CreatePanel("")
    mFilterBar.Color = 0xFFFFFFFF
    mPanel.AddView(mFilterBar, 0, 0, mPanel.Width, filterH)
    BuildFilterBar(filterH)

    ' --- ListView ---
    mListView = xui.CreateB4XListView
    mListView.SetLayoutAnimated(0, 0, filterH, mPanel.Width, mPanel.Height - filterH)
    mPanel.AddView(mListView, 0, filterH, mPanel.Width, mPanel.Height - filterH)

    ' --- Placeholder ריק ---
    mEmptyView = xui.CreatePanel("")
    mEmptyView.Visible = False
    mPanel.AddView(mEmptyView, 0, filterH, mPanel.Width, mPanel.Height - filterH)
    BuildEmptyView

    mListView.AddEventListener("ItemClick",       mEventObject, "TaskList_ItemClick")
    mListView.AddEventListener("ItemLongClick",   mEventObject, "TaskList_ItemLongClick")
End Sub

Private Sub BuildFilterBar(barH As Int)
    Dim filters() As String  = Array As String("הכל", "היום", "מחר", "דחוף", "הושלם")
    Dim filterIds() As String = Array As String("ALL", "TODAY", "TOMORROW", "URGENT", "DONE")

    Dim btnW As Int = mPanel.Width / filters.Length

    For i = 0 To filters.Length - 1
        Dim btn As B4XView = xui.CreateButton(filters(i))
        btn.TextSize  = 11
        btn.TextColor = 0xFF757575
        btn.Color     = 0x00000000
        btn.Tag       = filterIds(i)
        mFilterBar.AddView(btn, i * btnW, 0, btnW, barH)
        btn.AddEventListener("Click", mEventObject, "FilterBtn_Click")
    Next

    ' קו תחתי
    Dim divider As B4XView = xui.CreatePanel("")
    divider.Color = 0xFFE0E0E0
    mFilterBar.AddView(divider, 0, barH - 1, mPanel.Width, 1)
End Sub

Private Sub BuildEmptyView()
    Dim emojiLabel As B4XView = xui.CreateLabel("✅")
    emojiLabel.TextSize = 48
    emojiLabel.Gravity  = Gravity.CENTER
    mEmptyView.AddView(emojiLabel, 0, 60, mEmptyView.Width, 60)

    Dim textLabel As B4XView = xui.CreateLabel("אין משימות!")
    textLabel.TextColor = 0xFF9E9E9E
    textLabel.TextSize  = 16
    textLabel.Gravity   = Gravity.CENTER
    mEmptyView.AddView(textLabel, 0, 130, mEmptyView.Width, 30)

    Dim subLabel As B4XView = xui.CreateLabel("כל השיעורי בית הושלמו 🎉")
    subLabel.TextColor = 0xFFBDBDBD
    subLabel.TextSize  = 13
    subLabel.Gravity   = Gravity.CENTER
    mEmptyView.AddView(subLabel, 0, 165, mEmptyView.Width, 24)
End Sub

'-----------------------------------------------------------------------------
' טעינת משימות
'-----------------------------------------------------------------------------
Public Sub SetTasks(tasks As List)
    mAllTasks = tasks
    ApplyFilterAndRefresh
End Sub

Private Sub ApplyFilterAndRefresh()
    Dim filtered As List = ApplyFilter(mAllTasks, mFilter)
    Dim sorted   As List = SortTasks(filtered)
    RenderList(sorted)
End Sub

Private Sub ApplyFilter(tasks As List, filterStr As String) As List
    Dim result As List
    result.Initialize

    Dim todayStr    As String = mDtUtils.TsToDateStr(DateTime.Now)
    Dim tomorrowTs  As Long   = DateTime.Now + 86400000
    Dim tomorrowStr As String = mDtUtils.TsToDateStr(tomorrowTs)

    For i = 0 To tasks.Size - 1
        Dim task As FamilyTask = tasks.Get(i)
        Dim include As Boolean = False

        Select Case filterStr
            Case "ALL"
                include = task.Status <> "DONE" And task.Status <> "SKIPPED"
            Case "TODAY"
                include = task.DueDateStr = todayStr And task.Status <> "DONE"
            Case "TOMORROW"
                include = task.DueDateStr = tomorrowStr And task.Status <> "DONE"
            Case "URGENT"
                include = (task.Priority = "URGENT" Or task.Priority = "HIGH") And task.Status <> "DONE"
            Case "DONE"
                include = task.Status = "DONE"
        End Select

        If include Then result.Add(task)
    Next

    Return result
End Sub

' מיון: קודם דחוף, אחר-כך לפי מועד הגשה
Private Sub SortTasks(tasks As List) As List
    Dim n As Int = tasks.Size
    For i = 0 To n - 2
        For j = 0 To n - i - 2
            Dim a As FamilyTask = tasks.Get(j)
            Dim b As FamilyTask = tasks.Get(j + 1)
            If GetPriorityWeight(a.Priority) < GetPriorityWeight(b.Priority) Then
                tasks.Set(j,     b)
                tasks.Set(j + 1, a)
            Else If GetPriorityWeight(a.Priority) = GetPriorityWeight(b.Priority) Then
                If a.DueTs > b.DueTs And b.DueTs > 0 Then
                    tasks.Set(j,     b)
                    tasks.Set(j + 1, a)
                End If
            End If
        Next
    Next
    Return tasks
End Sub

Private Sub GetPriorityWeight(priority As String) As Int
    Select Case priority
        Case "URGENT" : Return 4
        Case "HIGH"   : Return 3
        Case "MEDIUM" : Return 2
        Case Else     : Return 1
    End Select
End Sub

'-----------------------------------------------------------------------------
' ציור הרשימה
'-----------------------------------------------------------------------------
Private Sub RenderList(tasks As List)
    mListView.Clear
    mCheckBoxMap.Initialize

    If tasks.Size = 0 Then
        mListView.Visible  = False
        mEmptyView.Visible = True
        Return
    End If

    mListView.Visible  = True
    mEmptyView.Visible = False

    Dim density As Float  = GetDeviceLayoutValues.Scale
    Dim rowH    As Int    = mConfig.TASK_ROW_HEIGHT_DP * density

    For i = 0 To tasks.Size - 1
        Dim task As FamilyTask = tasks.Get(i)
        Dim rowPanel As B4XView = BuildTaskRow(task, rowH)
        mListView.AddItem(task.Id, rowPanel, rowH)
    Next
End Sub

'-----------------------------------------------------------------------------
' בנייה של שורת משימה
'-----------------------------------------------------------------------------
Private Sub BuildTaskRow(task As FamilyTask, rowH As Int) As B4XView
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim rowPanel As B4XView = xui.CreatePanel("")
    rowPanel.Color = 0xFFFFFFFF

    ' פס עדיפות שמאלי
    Dim stripe As B4XView = xui.CreatePanel("")
    stripe.Color = xui.PaintOrColor(task.GetPriorityColor())
    rowPanel.AddView(stripe, 0, 4, 4, rowH - 8)

    ' Checkbox
    Dim checkbox As B4XView = xui.CreateCheckBox("")
    checkbox.Tag     = task.Id
    checkbox.Checked = task.IsDone
    rowPanel.AddView(checkbox, 12, rowH / 2 - 12, 24, 24)
    checkbox.AddEventListener("CheckedChange", mEventObject, "TaskCheck_Changed")
    mCheckBoxMap.Put(task.Id, checkbox)

    ' כותרת משימה
    Dim titleLabel As B4XView = xui.CreateLabel(task.Title)
    titleLabel.TextColor  = IIf(task.IsDone, 0xFF9E9E9E, 0xFF212121)
    titleLabel.TextSize   = 14
    titleLabel.TextStyle  = IIf(task.IsDone, Typeface.DEFAULT, Typeface.DEFAULT_BOLD)
    titleLabel.SingleLine = True
    If task.IsDone Then titleLabel.SetStrikeThru(True)
    rowPanel.AddView(titleLabel, 44, 10, rowPanel.Width - 140, 22)

    ' מקצוע (subject)
    If task.Subject <> "" Then
        Dim subjectLabel As B4XView = xui.CreateLabel(task.Subject)
        subjectLabel.TextColor = 0xFF757575
        subjectLabel.TextSize  = 11
        rowPanel.AddView(subjectLabel, 44, 34, 100, 16)
    End If

    ' מועד הגשה + Time Block
    Dim rightPanel As B4XView = xui.CreatePanel("")
    rightPanel.Color = 0x00000000
    rowPanel.AddView(rightPanel, rowPanel.Width - 130, 0, 130, rowH)
    BuildDueBadge(rightPanel, task, rowH)

    ' רקע אדום-שקוף אם עבר זמן
    If task.IsOverdue Then
        Dim overdueOverlay As B4XView = xui.CreatePanel("")
        overdueOverlay.Color = 0x15FF0000
        rowPanel.AddView(overdueOverlay, 0, 0, rowPanel.Width, rowH)
        rowPanel.SendToBack(overdueOverlay)
    End If

    Return rowPanel
End Sub

Private Sub BuildDueBadge(parent As B4XView, task As FamilyTask, rowH As Int)
    ' מועד הגשה
    Dim dueLabel As B4XView = xui.CreateLabel(FormatDueDate(task))
    dueLabel.TextColor = IIf(task.IsOverdue, 0xFFE53935, 0xFF757575)
    dueLabel.TextSize  = 11
    dueLabel.Gravity   = Gravity.RIGHT Or Gravity.TOP
    parent.AddView(dueLabel, 0, 10, parent.Width - 8, 16)

    ' Time Block
    If task.TimeBlockEnabled And task.TimeBlockStartTs > 0 Then
        Dim blockEndTs  As Long   = task.TimeBlockStartTs + (task.TimeBlockDurationMin * 60000)
        Dim blockLabel  As B4XView = xui.CreateLabel("⏱ " & mDtUtils.FormatTimeRange(task.TimeBlockStartTs, blockEndTs))
        blockLabel.TextColor = 0xFF3F51B5
        blockLabel.TextSize  = 10
        blockLabel.Gravity   = Gravity.RIGHT Or Gravity.TOP
        parent.AddView(blockLabel, 0, 30, parent.Width - 8, 16)
    End If

    ' תגית עדיפות
    If task.Priority = "URGENT" Then
        Dim urgentBadge As B4XView = xui.CreateLabel("🔥 דחוף")
        urgentBadge.TextColor = 0xFFFF3B30
        urgentBadge.TextSize  = 10
        urgentBadge.Gravity   = Gravity.RIGHT Or Gravity.BOTTOM
        parent.AddView(urgentBadge, 0, rowH - 22, parent.Width - 8, 16)
    End If
End Sub

Private Sub FormatDueDate(task As FamilyTask) As String
    If task.DueDateStr = "" Then Return ""
    Dim todayStr    As String = mDtUtils.TsToDateStr(DateTime.Now)
    Dim tomorrowStr As String = mDtUtils.TsToDateStr(DateTime.Now + 86400000)
    If task.DueDateStr = todayStr    Then Return "היום " & task.DueTimeStr
    If task.DueDateStr = tomorrowStr Then Return "מחר " & task.DueTimeStr
    Return task.DueDateStr & " " & task.DueTimeStr
End Sub

'-----------------------------------------------------------------------------
' אירועי UI
'-----------------------------------------------------------------------------
Sub FilterBtn_Click(view As B4XView)
    mFilter = view.Tag
    ApplyFilterAndRefresh
    UpdateFilterButtonStyles(view)
End Sub

Private Sub UpdateFilterButtonStyles(activeBtn As B4XView)
    For i = 0 To mFilterBar.NumberOfViews - 2   ' -2 = למעט הDivider
        Dim btn As B4XView = mFilterBar.GetView(i)
        If btn.Tag = activeBtn.Tag Then
            btn.TextColor = 0xFF1A237E
            btn.TextStyle = Typeface.DEFAULT_BOLD
        Else
            btn.TextColor = 0xFF757575
            btn.TextStyle = Typeface.DEFAULT
        End If
    Next
End Sub

Sub TaskCheck_Changed(view As B4XView, checked As Boolean)
    Dim taskId As String = view.Tag
    mDbManager.ToggleTaskDone(taskId, checked)
    RaiseEvent(mEventObject, "TaskToggled", Array(taskId, checked))
End Sub

Sub TaskList_ItemClick(index As Int, value As Object)
    Dim taskId As String = value
    RaiseEvent(mEventObject, "TaskSelected", Array(taskId))
End Sub

Sub TaskList_ItemLongClick(index As Int, value As Object)
    Dim taskId As String = value
    RaiseEvent(mEventObject, "TaskLongPressed", Array(taskId))
End Sub

' עדכון checkbox בודד ללא רענון מלא הרשימה
Public Sub RefreshTaskCheckbox(taskId As String, isDone As Boolean)
    If mCheckBoxMap.ContainsKey(taskId) Then
        Dim cb As B4XView = mCheckBoxMap.Get(taskId)
        cb.Checked = isDone
    End If
End Sub

Private Function IIf(condition As Boolean, trueVal As Object, falseVal As Object) As Object
    If condition Then Return trueVal
    Return falseVal
End Function
