'=============================================================================
' MainPage.bas — דף ראשי של האפליקציה (B4XPages)
' B4X Class Module
'
' תיאור: האקטיביטי הראשית המחברת את כל המודולים.
'         - Bottom Navigation: לוח שנה / משימות / חיפוש / פרופיל
'         - מאזין לכל אירועי Firebase
'         - מנהל את ה-Hot Update Banner
'         - מחלק אחריות לכל הרכיבים
'
' זרימת נתונים:
'   Firebase → DatabaseManager → EventManager → UI Components
'   UI Action → EventManager → DatabaseManager → Firebase → כל המשתמשים
'=============================================================================
Sub Class_Globals

    ' --- Managers ---
    Private mConfig       As AppConfig
    Private mAuth         As AuthManager
    Private mDbManager    As DatabaseManager
    Private mEvtManager   As EventManager
    Private mRecurMgr     As RecurringEventManager
    Private mSearchMgr    As SearchManager
    Private mStatsMgr     As StatsManager
    Private mNotifMgr     As NotificationManager
    Private mFCM          As FCMManager
    Private mDtUtils      As DateTimeUtils
    Private mIdGen        As IdGenerator
    Private mValidation   As ValidationUtils

    ' --- UI Components ---
    Private mWeekView     As CalendarWeekView
    Private mDayView      As DayView
    Private mTaskList     As TaskListView
    Private mBanner       As HotUpdateBanner
    Private mEventDialog  As EventDialog

    ' --- Panels ---
    Private mRootPanel    As B4XView
    Private mNavBar       As B4XView
    Private mCalendarPanel As B4XView
    Private mTasksPanel    As B4XView
    Private mSearchPanel   As B4XView
    Private mProfilePanel  As B4XView

    ' --- מצב ---
    Private mCurrentTab   As String = "CALENDAR"
    Private mCurrentUser  As FamilyUser
    Private mViewMode     As String = "WEEK"   ' WEEK / DAY
    Private mSelectedDate As String

    ' --- קבועי ניווט ---
    Private TAB_CALENDAR  As String = "CALENDAR"
    Private TAB_TASKS     As String = "TASKS"
    Private TAB_SEARCH    As String = "SEARCH"
    Private TAB_PROFILE   As String = "PROFILE"

    Private NAV_HEIGHT_DP As Int = 56

End Sub

'=============================================================================
' אתחול — נקרא ב-B4XPage_Created
'=============================================================================
Public Sub Initialize(rootPanel As B4XView)
    mRootPanel = rootPanel

    ' אתחול כל השירותים
    mConfig.Initialize
    mDtUtils.Initialize
    mIdGen.Initialize
    mValidation.Initialize

    mAuth.Initialize(mConfig, "MainPage")

    ' בדיקת כניסה אוטומטית
    If mAuth.TryAutoSignIn = False Then
        NavigateToLogin
        Return
    End If

    mCurrentUser = mAuth.GetCurrentUser

    SetupManagers
    BuildUI
    StartListening
End Sub

'=============================================================================
' הגדרת Managers
'=============================================================================
Private Sub SetupManagers()
    mDbManager.Initialize(mCurrentUser.FamilyId, mCurrentUser, "MainPage")
    mEvtManager.Initialize(mDbManager)
    mRecurMgr.Initialize(mDbManager)
    mSearchMgr.Initialize
    mStatsMgr.Initialize
    mNotifMgr.Initialize(mCurrentUser.FamilyId, mCurrentUser, Null, "MainPage")
    mFCM.Initialize(mCurrentUser.FamilyId, mCurrentUser.Id, "MainPage")
End Sub

'=============================================================================
' בנייה ראשונית של ה-UI
'=============================================================================
Private Sub BuildUI()
    Dim density As Float = GetDeviceLayoutValues.Scale
    Dim navH    As Int   = NAV_HEIGHT_DP * density
    Dim contentH As Int  = mRootPanel.Height - navH

    ' --- פאנלים לכרטיסיות ---
    mCalendarPanel = CreateFullPanel(contentH)
    mTasksPanel    = CreateFullPanel(contentH)
    mSearchPanel   = CreateFullPanel(contentH)
    mProfilePanel  = CreateFullPanel(contentH)

    mRootPanel.AddView(mCalendarPanel, 0, 0, mRootPanel.Width, contentH)
    mRootPanel.AddView(mTasksPanel,    0, 0, mRootPanel.Width, contentH)
    mRootPanel.AddView(mSearchPanel,   0, 0, mRootPanel.Width, contentH)
    mRootPanel.AddView(mProfilePanel,  0, 0, mRootPanel.Width, contentH)

    ' --- Nav Bar ---
    BuildNavBar(navH, contentH, density)

    ' --- אתחול קומפוננטות ---
    mWeekView.Initialize(mCalendarPanel, mEvtManager, mConfig, "MainPage")
    mDayView.Initialize(mCalendarPanel, mEvtManager, mConfig, "MainPage")
    mTaskList.Initialize(mTasksPanel, mDbManager, mConfig, "MainPage")
    mBanner.Initialize(mRootPanel, "MainPage")
    mEventDialog.Initialize(mRootPanel, mDbManager, mConfig, "MainPage")

    ' --- כפתור + (FAB) ---
    BuildFAB(density)

    ' --- מצב התחלה ---
    ShowTab(TAB_CALENDAR)
    mSelectedDate = mDtUtils.TsToDateStr(DateTime.Now)
    mWeekView.GoToCurrentWeek
End Sub

Private Sub CreateFullPanel(h As Int) As B4XView
    Dim p As B4XView = xui.CreatePanel("")
    p.Color   = 0xFFF5F5F5
    p.Visible = False
    Return p
End Sub

Private Sub BuildNavBar(navH As Int, contentH As Int, density As Float)
    mNavBar = xui.CreatePanel("")
    mNavBar.Color     = 0xFFFFFFFF
    mNavBar.Elevation = 8
    mRootPanel.AddView(mNavBar, 0, contentH, mRootPanel.Width, navH)

    Dim tabs() As String  = Array As String("CALENDAR", "TASKS", "SEARCH", "PROFILE")
    Dim icons() As String = Array As String("📅", "📚", "🔍", "👤")
    Dim labels() As String = Array As String("לוח שנה", "משימות", "חיפוש", "פרופיל")
    Dim tabW  As Int      = mRootPanel.Width / 4

    For i = 0 To 3
        Dim tabBtn As B4XView = xui.CreatePanel("")
        tabBtn.Tag = tabs(i)
        mNavBar.AddView(tabBtn, i * tabW, 0, tabW, navH)

        Dim iconLbl As B4XView = xui.CreateLabel(icons(i))
        iconLbl.TextSize = 20
        iconLbl.Gravity  = Gravity.CENTER_HORIZONTAL Or Gravity.TOP
        tabBtn.AddView(iconLbl, 0, 4 * density, tabW, 26 * density)

        Dim nameLbl As B4XView = xui.CreateLabel(labels(i))
        nameLbl.TextSize  = 10
        nameLbl.TextColor = 0xFF9E9E9E
        nameLbl.Gravity   = Gravity.CENTER
        nameLbl.Tag       = "label_" & tabs(i)
        tabBtn.AddView(nameLbl, 0, 28 * density, tabW, 16 * density)

        tabBtn.AddEventListener("Click", "MainPage", "NavTab_Click")
    Next
End Sub

Private Sub BuildFAB(density As Float)
    Dim fabSize As Int = 56 * density
    Dim fab As B4XView = xui.CreateButton("+")
    fab.TextSize  = 24
    fab.TextColor = 0xFFFFFFFF
    fab.Color     = 0xFF1A237E
    fab.Elevation = 6
    mRootPanel.AddView(fab, mRootPanel.Width - fabSize - 16 * density, _
        mRootPanel.Height - NAV_HEIGHT_DP * density - fabSize - 16 * density, _
        fabSize, fabSize)
    fab.AddEventListener("Click", "MainPage", "FAB_Click")
End Sub

'=============================================================================
' ניווט בין כרטיסיות
'=============================================================================
Private Sub ShowTab(tabId As String)
    mCurrentTab = tabId
    mCalendarPanel.Visible = (tabId = TAB_CALENDAR)
    mTasksPanel.Visible    = (tabId = TAB_TASKS)
    mSearchPanel.Visible   = (tabId = TAB_SEARCH)
    mProfilePanel.Visible  = (tabId = TAB_PROFILE)
End Sub

Sub NavTab_Click(view As B4XView)
    ShowTab(view.Tag)
End Sub

Sub FAB_Click(view As B4XView)
    Select Case mCurrentTab
        Case TAB_CALENDAR
            mEventDialog.OpenForCreate(mSelectedDate)
        Case TAB_TASKS
            ' פתח דיאלוג משימה חדשה
            RaiseEvent("MainPage", "OpenNewTask", Null)
    End Select
End Sub

'=============================================================================
' האזנה ל-Firebase
'=============================================================================
Private Sub StartListening()
    mDbManager.StartListeningToEvents
    mDbManager.StartListeningToTasks
    mNotifMgr.StartListening
    mFCM.SubscribeToFamilyTopic
    mFCM.RefreshToken
End Sub

'=============================================================================
' אירועי Firebase — מגיעים ל-MainPage
'=============================================================================

' כל האירועים נטענו / עודכנו
Sub MainPage_EventsLoaded(events As List)
    mEvtManager.SetEvents(events)
    mRecurMgr.SetTemplates(events)
    mSearchMgr.SetData(events, mAllTasks)
    mStatsMgr.SetData(events, mAllTasks)
    RefreshCalendarView
End Sub

' כל המשימות נטענו / עודכנו
Sub MainPage_TasksLoaded(tasks As List)
    mAllTasks = tasks
    mTaskList.SetTasks(tasks)
    mSearchMgr.SetData(mAllEvents, tasks)
    mStatsMgr.SetData(mAllEvents, tasks)
End Sub

Private mAllEvents As List
Private mAllTasks  As List

' עדכון badge התראות
Sub MainPage_NotificationsBadgeUpdated(count As Int, unreadList As List)
    UpdateNotifBadge(count)
    ShowLatestNotification(unreadList)
End Sub

' Push Notification הגיע כשהאפליקציה פתוחה
Sub MainPage_PushReceived(title As String, body As String, data As Map)
    Dim notifType As String = ""
    If data.ContainsKey("type") Then notifType = data.Get("type")
    mBanner.Show(title, body, notifType, "")
End Sub

' שגיאת Firebase
Sub MainPage_Error(message As String)
    Log("Firebase Error: " & message)
    ShowToast(message)
End Sub

'=============================================================================
' אירועי UI — מרכיבי Calendar
'=============================================================================

' לחיצה על בלוק אירוע בתצוגה שבועית
Sub MainPage_EventSelected(eventId As String)
    Dim evt As CalendarEvent = mDbManager.GetCachedEvent(eventId)
    If evt.Id = "" Then Return
    ShowEventDetails(evt)
End Sub

' לחיצה על אירוע בתצוגה יומית
Sub MainPage_DayEventSelected(eventId As String)
    Dim evt As CalendarEvent = mDbManager.GetCachedEvent(eventId)
    If evt.Id = "" Then Return
    ShowEventDetails(evt)
End Sub

' לחיצה על באנר Hot Update
Sub MainPage_BannerTapped(refId As String)
    If refId <> "" Then
        Dim evt As CalendarEvent = mDbManager.GetCachedEvent(refId)
        If evt.Id <> "" Then ShowEventDetails(evt)
    End If
    mNotifMgr.MarkAllAsRead
End Sub

' אירוע נשמר
Sub MainPage_EventSaved(evt As CalendarEvent)
    ShowToast("האירוע נשמר בהצלחה")
End Sub

' Toggle checkbox משימה
Sub MainPage_TaskToggled(taskId As String, isDone As Boolean)
    Dim msg As String = IIf(isDone, "המשימה הושלמה!", "המשימה עודכנה")
    ShowToast(msg)
End Sub

' לחיצה על משימה → פרטים
Sub MainPage_TaskSelected(taskId As String)
    Log("Task selected: " & taskId)
End Sub

'=============================================================================
' פעולות Hot Update מהירות
'=============================================================================

' הזזת אירוע (נקרא ממסך פרטי אירוע)
Public Sub MoveEvent(eventId As String, newStartTs As Long, note As String)
    mEvtManager.MoveEvent(eventId, newStartTs, 0, note)
    ShowToast("האירוע הוזז")
End Sub

' ביטול אירוע
Public Sub CancelEvent(eventId As String, reason As String)
    mEvtManager.CancelEvent(eventId, reason)
    ShowToast("האירוע בוטל")
End Sub

'=============================================================================
' עזרי תצוגה
'=============================================================================

Private Sub RefreshCalendarView()
    If mViewMode = "WEEK" Then
        mWeekView.ShowWeek(mWeekView.GetCurrentWeekStart)
    Else
        mDayView.ShowDate(mSelectedDate)
    End If
End Sub

Private Sub ShowEventDetails(evt As CalendarEvent)
    ' כאן תפתח דף פרטים / Bottom Sheet עם:
    ' - כל פרטי האירוע
    ' - כפתורי Hot Update (הזז / בטל / ערוך)
    Log("Show details for: " & evt.Title)
    mEventDialog.OpenForEdit(evt)
End Sub

Private Sub UpdateNotifBadge(count As Int)
    ' עדכן badge על כרטיסיית הפרופיל / פעמון
    Log("Unread notifications: " & count)
End Sub

Private Sub ShowLatestNotification(unreadList As List)
    If unreadList.Size = 0 Then Return
    Dim latest As Map = unreadList.Get(unreadList.Size - 1)
    If latest.ContainsKey("message") Then
        Dim notifType As String = IIf(latest.ContainsKey("type"), latest.Get("type"), "")
        Dim refId     As String = IIf(latest.ContainsKey("ref_id"), latest.Get("ref_id"), "")
        mBanner.Show(latest.Get("message"), "", notifType, refId)
    End If
End Sub

Private Sub NavigateToLogin()
    Log("Navigate to login screen")
End Sub

Private Sub ShowToast(msg As String)
    Dim t As B4XToast
    t.Show(msg, False)
End Sub

Private Function IIf(condition As Boolean, trueVal As String, falseVal As String) As String
    If condition Then Return trueVal
    Return falseVal
End Function
