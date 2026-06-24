'=============================================================================
' EventDialog.bas — דיאלוג יצירה ועריכת אירוע
' B4X Class Module
'
' תיאור: Bottom Sheet / Dialog מלא ליצירה ועריכה.
'         - בחירת קטגוריה עם chips צבעוניות
'         - בוחר שעה (TimePicker)
'         - סטטוס מהיר (Hot Update)
'         - סימון אירוע חוזר
'         - ולידציה לפני שמירה
'
' שימוש:
'   Dim dialog As EventDialog
'   dialog.Initialize(RootPanel, DbManager, "Dialog")
'   dialog.OpenForCreate("2024-11-15")
'   dialog.OpenForEdit(existingEvent)
'=============================================================================
Sub Class_Globals

    Private mRootPanel   As B4XView
    Private mDbManager   As DatabaseManager
    Private mConfig      As AppConfig
    Private mDtUtils     As DateTimeUtils
    Private mEventObject As String

    Private mOverlay     As B4XView   ' רקע כהה
    Private mSheet       As B4XView   ' פאנל הדיאלוג עצמו
    Private mIsOpen      As Boolean

    ' שדות הטופס
    Private mTitleField       As B4XView
    Private mCategoryChips    As List   ' Map לכל chip
    Private mDateLabel        As B4XView
    Private mStartTimePicker  As TimePicker
    Private mEndTimePicker    As TimePicker
    Private mLocationField    As B4XView
    Private mStatusSpinner    As Spinner
    Private mStatusNoteField  As B4XView
    Private mRecurringSwitch  As B4XView
    Private mRecurringOptions As B4XView
    Private mDescField        As B4XView

    ' מצב עריכה
    Private mIsEditMode    As Boolean
    Private mCurrentEvent  As CalendarEvent
    Private mSelectedDate  As String
    Private mSelectedCategory As String

    Private SHEET_HEIGHT_RATIO As Float = 0.88

End Sub

'-----------------------------------------------------------------------------
' אתחול
'-----------------------------------------------------------------------------
Public Sub Initialize(rootPanel As B4XView, dbMgr As DatabaseManager, _
                       config As AppConfig, eventObject As String)
    mRootPanel   = rootPanel
    mDbManager   = dbMgr
    mConfig      = config
    mEventObject = eventObject
    mDtUtils.Initialize
    mCategoryChips.Initialize
    mIsOpen = False
    BuildDialog
End Sub

'-----------------------------------------------------------------------------
' בנייה
'-----------------------------------------------------------------------------
Private Sub BuildDialog()
    Dim density As Float  = GetDeviceLayoutValues.Scale
    Dim sheetH  As Int    = CInt(mRootPanel.Height * SHEET_HEIGHT_RATIO)

    ' רקע כהה
    mOverlay = xui.CreatePanel("")
    mOverlay.Color = 0x80000000
    mOverlay.Visible = False
    mRootPanel.AddView(mOverlay, 0, 0, mRootPanel.Width, mRootPanel.Height)
    mOverlay.AddEventListener("Click", mEventObject, "Overlay_Click")

    ' גיליון
    mSheet = xui.CreatePanel("")
    mSheet.Color = 0xFFFFFFFF
    mSheet.Visible = False
    mRootPanel.AddView(mSheet, 0, mRootPanel.Height, mRootPanel.Width, sheetH)
    SetTopRoundedCorners(mSheet, 20 * density)

    BuildFormContent(density)
End Sub

Private Sub BuildFormContent(density As Float)
    Dim pad As Int = 16 * density
    Dim y   As Int = 20 * density

    ' ידית גרירה
    Dim handle As B4XView = xui.CreatePanel("")
    handle.Color = 0xFFBDBDBD
    mSheet.AddView(handle, mSheet.Width / 2 - 20 * density, 8 * density, 40 * density, 4 * density)
    SetRoundedCorners(handle, 2 * density)

    ' כותרת הדיאלוג
    Dim headerLabel As B4XView = xui.CreateLabel("אירוע חדש")
    headerLabel.TextSize  = 18
    headerLabel.TextStyle = Typeface.DEFAULT_BOLD
    headerLabel.TextColor = 0xFF1A237E
    headerLabel.Gravity   = Gravity.RIGHT Or Gravity.CENTER_VERTICAL
    mSheet.AddView(headerLabel, pad, y, mSheet.Width - 2 * pad, 30 * density)
    y = y + 40 * density

    ' --- שדה כותרת ---
    Dim titleHint As B4XView = xui.CreateLabel("שם האירוע *")
    titleHint.TextColor = 0xFF757575
    titleHint.TextSize  = 12
    mSheet.AddView(titleHint, pad, y, 200 * density, 18 * density)
    y = y + 22 * density

    mTitleField = xui.CreateEditText("")
    mTitleField.Hint      = "למשל: חוג שחייה"
    mTitleField.TextSize  = 16
    mTitleField.InputType = EditText.INPUT_TYPE_WORDS_CAPITALIZED
    mSheet.AddView(mTitleField, pad, y, mSheet.Width - 2 * pad, 44 * density)
    y = y + 52 * density

    ' --- קטגוריות (Chips) ---
    Dim catHint As B4XView = xui.CreateLabel("קטגוריה")
    catHint.TextColor = 0xFF757575
    catHint.TextSize  = 12
    mSheet.AddView(catHint, pad, y, 200 * density, 18 * density)
    y = y + 22 * density

    BuildCategoryChips(pad, y, density)
    y = y + 44 * density

    ' --- תאריך ---
    mDateLabel = xui.CreateButton("📅 בחר תאריך")
    mDateLabel.TextSize  = 14
    mDateLabel.TextColor = 0xFF1A237E
    mDateLabel.Color     = 0xFFF3F4F6
    mSheet.AddView(mDateLabel, pad, y, mSheet.Width - 2 * pad, 40 * density)
    mDateLabel.AddEventListener("Click", mEventObject, "DateBtn_Click")
    y = y + 48 * density

    ' --- שעה ---
    Dim timeHint As B4XView = xui.CreateLabel("שעת התחלה — סיום")
    timeHint.TextColor = 0xFF757575
    timeHint.TextSize  = 12
    mSheet.AddView(timeHint, pad, y, 200 * density, 18 * density)
    y = y + 22 * density

    Dim timePanel As B4XView = xui.CreatePanel("")
    mSheet.AddView(timePanel, pad, y, mSheet.Width - 2 * pad, 40 * density)
    ' TimePickers
    mStartTimePicker.Initialize("START", 8, 0)
    mEndTimePicker.Initialize("END", 9, 0)
    y = y + 48 * density

    ' --- מיקום ---
    mLocationField = xui.CreateEditText("")
    mLocationField.Hint = "מיקום (לא חובה)"
    mLocationField.TextSize = 14
    mSheet.AddView(mLocationField, pad, y, mSheet.Width - 2 * pad, 40 * density)
    y = y + 48 * density

    ' --- סטטוס (Hot Update) ---
    Dim statusHint As B4XView = xui.CreateLabel("סטטוס")
    statusHint.TextColor = 0xFF757575
    statusHint.TextSize  = 12
    mSheet.AddView(statusHint, pad, y, 200 * density, 18 * density)
    y = y + 22 * density

    BuildStatusChips(pad, y, density)
    y = y + 44 * density

    ' --- הערה לסטטוס ---
    mStatusNoteField = xui.CreateEditText("")
    mStatusNoteField.Hint    = "הסבר לשינוי (למשל: המאמן ביקש)"
    mStatusNoteField.TextSize = 13
    mStatusNoteField.Visible  = False
    mSheet.AddView(mStatusNoteField, pad, y, mSheet.Width - 2 * pad, 36 * density)
    y = y + 44 * density

    ' --- חוזרניות ---
    Dim recurPanel As B4XView = xui.CreatePanel("")
    recurPanel.Color = 0x00000000
    mSheet.AddView(recurPanel, pad, y, mSheet.Width - 2 * pad, 36 * density)
    Dim recurLabel As B4XView = xui.CreateLabel("אירוע שבועי חוזר")
    recurLabel.TextSize = 14
    recurPanel.AddView(recurLabel, 0, 6 * density, recurPanel.Width - 56 * density, 24 * density)
    mRecurringSwitch = xui.CreateSwitch("")
    mRecurringSwitch.Tag = "recurring"
    recurPanel.AddView(mRecurringSwitch, recurPanel.Width - 52 * density, 4 * density, 48 * density, 28 * density)
    y = y + 44 * density

    ' --- כפתורי שמירה / ביטול ---
    Dim btnPanel As B4XView = xui.CreatePanel("")
    mSheet.AddView(btnPanel, pad, mSheet.Height - 60 * density, mSheet.Width - 2 * pad, 48 * density)

    Dim cancelBtn As B4XView = xui.CreateButton("ביטול")
    cancelBtn.TextColor = 0xFF757575
    cancelBtn.Color     = 0xFFEEEEEE
    btnPanel.AddView(cancelBtn, 0, 0, (btnPanel.Width - 8 * density) / 2, 44 * density)
    cancelBtn.AddEventListener("Click", mEventObject, "DialogCancel_Click")

    Dim saveBtn As B4XView = xui.CreateButton("שמור")
    saveBtn.TextColor = 0xFFFFFFFF
    saveBtn.Color     = 0xFF1A237E
    btnPanel.AddView(saveBtn, (btnPanel.Width + 8 * density) / 2, 0, (btnPanel.Width - 8 * density) / 2, 44 * density)
    saveBtn.AddEventListener("Click", mEventObject, "DialogSave_Click")
End Sub

Private Sub BuildCategoryChips(x As Int, y As Int, density As Float)
    Dim categories() As String = Array As String("CHUGIM", "HOMEWORK", "FAMILY", "FRIENDS", "OTHER")
    Dim names()      As String = Array As String("חוגים", "שיעורי בית", "משפחה", "חברים", "אחר")
    Dim chipW        As Int    = 70 * density
    Dim chipH        As Int    = 32 * density

    mCategoryChips.Initialize

    For i = 0 To categories.Length - 1
        Dim chip As B4XView = xui.CreateButton(names(i))
        chip.TextSize  = 11
        chip.Tag       = categories(i)
        ApplyChipStyle(chip, categories(i), False)
        mSheet.AddView(chip, x + i * (chipW + 6 * density), y, chipW, chipH)
        chip.AddEventListener("Click", mEventObject, "CategoryChip_Click")
        mCategoryChips.Add(chip)
    Next

    mSelectedCategory = "CHUGIM"
    ApplyChipStyle(mCategoryChips.Get(0), "CHUGIM", True)
End Sub

Private Sub BuildStatusChips(x As Int, y As Int, density As Float)
    Dim statuses() As String = Array As String("ON_TIME", "MOVED", "CANCELED", "POSTPONED")
    Dim labels()   As String = Array As String("בזמן", "הוזז", "בוטל", "נדחה")
    Dim chipW      As Int    = 68 * density
    Dim chipH      As Int    = 32 * density

    For i = 0 To statuses.Length - 1
        Dim chip As B4XView = xui.CreateButton(labels(i))
        chip.TextSize = 11
        chip.Tag      = statuses(i)
        Dim chipColor As String = mConfig.GetStatusColor(statuses(i))
        chip.Color    = xui.PaintOrColor(chipColor)
        chip.TextColor = 0xFFFFFFFF
        mSheet.AddView(chip, x + i * (chipW + 6 * density), y, chipW, chipH)
        chip.AddEventListener("Click", mEventObject, "StatusChip_Click")
    Next
End Sub

Private Sub ApplyChipStyle(chip As B4XView, category As String, isSelected As Boolean)
    Dim colorHex As String = mConfig.GetCategoryColor(category)
    If isSelected Then
        chip.Color     = xui.PaintOrColor(colorHex)
        chip.TextColor = 0xFFFFFFFF
    Else
        chip.Color     = 0xFFEEEEEE
        chip.TextColor = 0xFF424242
    End If
End Sub

'-----------------------------------------------------------------------------
' פתיחת הדיאלוג
'-----------------------------------------------------------------------------
Public Sub OpenForCreate(dateStr As String)
    mIsEditMode   = False
    mSelectedDate = dateStr
    mCurrentEvent.Initialize

    ' איפוס שדות
    mTitleField.Text     = ""
    mLocationField.Text  = ""
    mStatusNoteField.Text = ""
    mStatusNoteField.Visible = False
    mDateLabel.Text      = "📅 " & mDtUtils.FormatDateHebrew(mDtUtils.DateStrToTs(dateStr))
    mSelectedCategory    = "CHUGIM"
    ApplyChipStyle(mCategoryChips.Get(0), "CHUGIM", True)

    ShowSheet
End Sub

Public Sub OpenForEdit(evt As CalendarEvent)
    mIsEditMode   = True
    mCurrentEvent = evt
    mSelectedDate = evt.DateStr

    ' מילוי השדות
    mTitleField.Text    = evt.Title
    mLocationField.Text = evt.Location
    mDateLabel.Text     = "📅 " & mDtUtils.FormatDateHebrew(mDtUtils.DateStrToTs(mDtUtils.DateStrToTs(evt.DateStr)))
    mStatusNoteField.Text = evt.StatusNote
    mStatusNoteField.Visible = evt.Status <> "ON_TIME"
    mSelectedCategory   = evt.Category

    UpdateCategoryChipStyles

    ShowSheet
End Sub

Private Sub ShowSheet()
    mOverlay.Visible = True
    mSheet.Visible   = True
    mIsOpen          = True
    mSheet.SetLayoutAnimated(250, 0, mRootPanel.Height - mSheet.Height, mSheet.Width, mSheet.Height)
End Sub

Public Sub Close()
    mSheet.SetLayoutAnimated(250, 0, mRootPanel.Height, mSheet.Width, mSheet.Height)
    Sleep(280)
    mSheet.Visible   = False
    mOverlay.Visible = False
    mIsOpen          = False
End Sub

'-----------------------------------------------------------------------------
' אירועי UI
'-----------------------------------------------------------------------------
Sub CategoryChip_Click(view As B4XView)
    mSelectedCategory = view.Tag
    UpdateCategoryChipStyles
End Sub

Private Sub UpdateCategoryChipStyles()
    For i = 0 To mCategoryChips.Size - 1
        Dim chip As B4XView = mCategoryChips.Get(i)
        ApplyChipStyle(chip, chip.Tag, chip.Tag = mSelectedCategory)
    Next
End Sub

Sub StatusChip_Click(view As B4XView)
    Dim status As String = view.Tag
    mStatusNoteField.Visible = (status <> "ON_TIME")
    mCurrentEvent.Status = status
End Sub

Sub DateBtn_Click(view As B4XView)
    Dim dp As DatePicker
    dp.Show(mEventObject, "DatePicker", mSelectedDate)
End Sub

Sub DatePicker_DateChanged(year As Int, month As Int, day As Int)
    mSelectedDate = year & "-" & NumberFormat2(month, 2, 0, 0, False) & "-" & NumberFormat2(day, 2, 0, 0, False)
    mDateLabel.Text = "📅 " & mDtUtils.FormatDateHebrew(mDtUtils.DateStrToTs(mSelectedDate))
End Sub

Sub DialogCancel_Click(view As B4XView)
    Close
End Sub

Sub DialogSave_Click(view As B4XView)
    If Not Validate() Then Return
    SaveEvent
    Close
End Sub

Sub Overlay_Click(view As B4XView)
    Close
End Sub

'-----------------------------------------------------------------------------
' ולידציה
'-----------------------------------------------------------------------------
Private Sub Validate() As Boolean
    If mTitleField.Text.Trim = "" Then
        ShowError("יש להזין שם לאירוע")
        mTitleField.RequestFocus
        Return False
    End If
    If mSelectedDate = "" Then
        ShowError("יש לבחור תאריך")
        Return False
    End If
    Return True
End Sub

Private Sub ShowError(msg As String)
    Dim toast As B4XToast
    toast.Show(msg, True)
End Sub

'-----------------------------------------------------------------------------
' שמירה
'-----------------------------------------------------------------------------
Private Sub SaveEvent()
    If mIsEditMode = False Then mCurrentEvent.Initialize

    mCurrentEvent.Title    = mTitleField.Text.Trim
    mCurrentEvent.Category = mSelectedCategory
    mCurrentEvent.Location = mLocationField.Text.Trim
    mCurrentEvent.DateStr  = mSelectedDate
    mCurrentEvent.StatusNote = mStatusNoteField.Text.Trim

    ' זמנים
    Dim dateTs     As Long = mDtUtils.DateStrToTs(mSelectedDate)
    Dim startTs    As Long = mDtUtils.CombineDateAndTimeStr(dateTs, mStartTimePicker.GetTime)
    Dim endTs      As Long = mDtUtils.CombineDateAndTimeStr(dateTs, mEndTimePicker.GetTime)

    If mIsEditMode = False Then
        mCurrentEvent.OriginalStartTs = startTs
        mCurrentEvent.OriginalEndTs   = endTs
    End If
    mCurrentEvent.CurrentStartTs = startTs
    mCurrentEvent.CurrentEndTs   = endTs

    mDbManager.SaveEvent(mCurrentEvent)
    RaiseEvent(mEventObject, "EventSaved", Array(mCurrentEvent))
End Sub

Private Sub SetTopRoundedCorners(v As B4XView, radius As Int)
    ' ב-B4A: שימוש ב-XUI Elevation
    v.Elevation = 12
End Sub

Private Sub SetRoundedCorners(v As B4XView, radius As Int)
    v.Elevation = 0
End Sub
