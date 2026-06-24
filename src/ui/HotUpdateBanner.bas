'=============================================================================
' HotUpdateBanner.bas — באנר התראה בזמן אמת (Hot Update)
' B4X Class Module
'
' תיאור: פאנל שמופיע מלמעלה (Slide-in animation) כשאירוע מוזז / בוטל.
'         נעלם אוטומטית לאחר 5 שניות, או בלחיצה.
'         ניתן להצטבר — מציג תור של הודעות.
'
' שימוש:
'   Dim banner As HotUpdateBanner
'   banner.Initialize(RootPanel, "Banner")
'   banner.Show("חוג שחייה הוזז ל-17:00", "MOVED", "evt_xyz")
'=============================================================================
Sub Class_Globals

    Private mRootPanel   As B4XView
    Private mEventObject As String

    Private mBannerView  As B4XView
    Private mIconLabel   As B4XView
    Private mTitleLabel  As B4XView
    Private mBodyLabel   As B4XView
    Private mCloseBtn    As B4XView

    Private mQueue        As List   ' Map של {text, type, refId}
    Private mIsShowing    As Boolean
    Private mAutoHideTimer As Timer

    Private ANIM_DURATION_MS As Int = 300
    Private AUTO_HIDE_MS      As Int = 5000
    Private BANNER_H_DP       As Int = 72

End Sub

'-----------------------------------------------------------------------------
' אתחול
'-----------------------------------------------------------------------------
Public Sub Initialize(rootPanel As B4XView, eventObject As String)
    mRootPanel   = rootPanel
    mEventObject = eventObject
    mQueue.Initialize
    mIsShowing = False

    BuildBannerView
    mAutoHideTimer.Initialize(mEventObject, "AutoHide", AUTO_HIDE_MS)
    mAutoHideTimer.Enabled = False
End Sub

'-----------------------------------------------------------------------------
' בנייה ראשונית של הבאנר (מוסתר מתחת לגבול העליון)
'-----------------------------------------------------------------------------
Private Sub BuildBannerView()
    Dim bannerH As Int = BANNER_H_DP * GetDensity()

    mBannerView = xui.CreatePanel("")
    mBannerView.Color = 0xFF1A237E
    mBannerView.Elevation = 8
    mRootPanel.AddView(mBannerView, 0, -bannerH, mRootPanel.Width, bannerH)

    ' אייקון שמאלי
    mIconLabel = xui.CreateLabel("📅")
    mIconLabel.TextSize = 22
    mIconLabel.Gravity  = Gravity.CENTER
    mBannerView.AddView(mIconLabel, 12, 0, bannerH, bannerH)

    ' טקסט כותרת
    mTitleLabel = xui.CreateLabel("")
    mTitleLabel.TextColor = 0xFFFFFFFF
    mTitleLabel.TextSize  = 13
    mTitleLabel.TextStyle = Typeface.DEFAULT_BOLD
    mTitleLabel.Gravity   = Gravity.RIGHT Or Gravity.TOP
    mBannerView.AddView(mTitleLabel, bannerH, 12, mBannerView.Width - bannerH - 40, 20)

    ' טקסט גוף
    mBodyLabel = xui.CreateLabel("")
    mBodyLabel.TextColor = 0xCCFFFFFF
    mBodyLabel.TextSize  = 11
    mBodyLabel.Gravity   = Gravity.RIGHT Or Gravity.TOP
    mBodyLabel.SingleLine = True
    mBannerView.AddView(mBodyLabel, bannerH, 34, mBannerView.Width - bannerH - 40, 18)

    ' כפתור סגירה
    mCloseBtn = xui.CreateLabel("✕")
    mCloseBtn.TextColor = 0xAAFFFFFF
    mCloseBtn.TextSize  = 16
    mCloseBtn.Gravity   = Gravity.CENTER
    mBannerView.AddView(mCloseBtn, mBannerView.Width - 36, 0, 36, bannerH)

    ' לחיצות
    mBannerView.AddEventListener("Click", mEventObject, "Banner_Click")
    mCloseBtn.AddEventListener("Click",   mEventObject, "BannerClose_Click")
End Sub

'-----------------------------------------------------------------------------
' הצגת הודעה
'-----------------------------------------------------------------------------
Public Sub Show(title As String, body As String, eventType As String, refId As String)
    Dim msg As Map
    msg.Initialize
    msg.Put("title",  title)
    msg.Put("body",   body)
    msg.Put("type",   eventType)
    msg.Put("ref_id", refId)
    mQueue.Add(msg)

    If mIsShowing = False Then ShowNext
End Sub

Private Sub ShowNext()
    If mQueue.Size = 0 Then Return

    Dim msg As Map = mQueue.Get(0)
    mQueue.RemoveAt(0)
    mIsShowing = True

    ' עדכן תוכן
    ApplyMessageStyle(msg)

    ' Slide-in מלמעלה
    Dim bannerH As Int = mBannerView.Height
    mBannerView.SetLayoutAnimated(ANIM_DURATION_MS, 0, 0, mBannerView.Width, bannerH)

    ' טיימר להסתרה אוטומטית
    mAutoHideTimer.Enabled = False
    mAutoHideTimer.Enabled = True
End Sub

' עדכון צבע ואייקון לפי סוג האירוע
Private Sub ApplyMessageStyle(msg As Map)
    Dim eventType As String = msg.Get("type")
    mTitleLabel.Text = msg.Get("title")
    mBodyLabel.Text  = msg.Get("body")
    mBannerView.Tag  = msg.Get("ref_id")

    Select Case eventType
        Case "MOVED", "RESCHEDULED"
            mBannerView.Color = 0xFFF39C12   ' כתום
            mIconLabel.Text   = "⏰"
        Case "CANCELED"
            mBannerView.Color = 0xFFE74C3C   ' אדום
            mIconLabel.Text   = "❌"
        Case "POSTPONED"
            mBannerView.Color = 0xFF9B59B6   ' סגול
            mIconLabel.Text   = "⏩"
        Case "NEW_EVENT"
            mBannerView.Color = 0xFF2ECC71   ' ירוק
            mIconLabel.Text   = "🆕"
        Case "TASK_DUE"
            mBannerView.Color = 0xFF3498DB   ' כחול
            mIconLabel.Text   = "📚"
        Case Else
            mBannerView.Color = 0xFF1A237E
            mIconLabel.Text   = "📅"
    End Select
End Sub

'-----------------------------------------------------------------------------
' הסתרה
'-----------------------------------------------------------------------------
Public Sub Hide()
    mAutoHideTimer.Enabled = False
    Dim bannerH As Int = mBannerView.Height
    mBannerView.SetLayoutAnimated(ANIM_DURATION_MS, 0, -bannerH, mBannerView.Width, bannerH)
    Sleep(ANIM_DURATION_MS + 50)
    mIsShowing = False
    If mQueue.Size > 0 Then ShowNext
End Sub

Sub AutoHide_Tick
    Hide
End Sub

Sub Banner_Click(view As B4XView)
    RaiseEvent(mEventObject, "BannerTapped", Array(view.Tag))
    Hide
End Sub

Sub BannerClose_Click(view As B4XView)
    Hide
End Sub

' כמה הודעות בתור?
Public Sub GetQueueSize() As Int
    Return mQueue.Size
End Sub

Public Sub ClearQueue()
    mQueue.Initialize
    If mIsShowing Then Hide
End Sub

Private Sub GetDensity() As Float
    Return GetDeviceLayoutValues.Scale
End Sub
