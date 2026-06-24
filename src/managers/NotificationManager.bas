'=============================================================================
' NotificationManager.bas — מנהל התראות ו-Hot Update Badges
' B4X Class Module
'
' תיאור: מאזין לנתיב /notifications ב-Firebase ומציג ל-UI
'         כמה עדכונים לא-נקראים יש, ואיזה אירועים השתנו.
'=============================================================================
Sub Class_Globals

    Private mFamilyId    As String
    Private mCurrentUser As FamilyUser
    Private mDb          As FirebaseDatabase
    Private mNotifsRef   As DatabaseReference
    Private mListener    As ValueEventListener
    Private mEventObject As String

    Private mUnreadCount As Int
    Private mUnreadList  As List

End Sub

Public Sub Initialize(familyId As String, currentUser As FamilyUser, db As FirebaseDatabase, eventObject As String)
    mFamilyId    = familyId
    mCurrentUser = currentUser
    mDb          = db
    mEventObject = eventObject
    mUnreadCount = 0
    mUnreadList.Initialize
    mNotifsRef = db.GetReference("families/" & familyId & "/notifications")
End Sub

Public Sub StartListening()
    ' מאזינים רק להתראות חדשות (24 שעות אחרונות) — לא כל ההיסטוריה
    Dim cutoff As Long = DateTime.Now - 86400000
    Dim q As Query = mNotifsRef.OrderByChild("created_at").StartAt(cutoff)
    mListener = q.AddValueEventListener(mEventObject, "Notifications")
End Sub

Public Sub StopListening()
    If mListener.IsInitialized Then mNotifsRef.RemoveEventListener(mListener)
End Sub

Sub Notifications_ValueChanged(snapshot As DataSnapshot)
    If snapshot.Exists = False Then Return

    mUnreadList.Initialize
    mUnreadCount = 0

    Dim allData As Map = snapshot.Value
    For i = 0 To allData.Size - 1
        Dim notif As Map = allData.GetValueAt(i)

        ' האם המשתמש הנוכחי כבר קרא את זה?
        Dim readBy As Map
        Dim isRead As Boolean = False
        If notif.ContainsKey("read_by") Then
            readBy = notif.Get("read_by")
            isRead = readBy.ContainsKey(mCurrentUser.Id)
        End If

        If isRead = False Then
            mUnreadList.Add(notif)
            mUnreadCount = mUnreadCount + 1
        End If
    Next

    RaiseEvent(mEventObject, "NotificationsBadgeUpdated", Array(mUnreadCount, mUnreadList))
End Sub

Sub Notifications_Cancelled(error As DatabaseError)
    ' שקט
End Sub

' סמן התראה כנקראה
Public Sub MarkAsRead(notifId As String)
    Dim path As String = "families/" & mFamilyId & "/notifications/" & notifId & "/read_by/" & mCurrentUser.Id
    mDb.GetReference(path).SetValue(DateTime.Now, mEventObject, "MarkRead")
End Sub

Sub MarkRead_Complete(success As Boolean) : End Sub

' סמן הכל כנקרא
Public Sub MarkAllAsRead()
    For i = 0 To mUnreadList.Size - 1
        Dim notif As Map = mUnreadList.Get(i)
        If notif.ContainsKey("id") Then MarkAsRead(notif.Get("id"))
    Next
End Sub

Public Sub GetUnreadCount() As Int
    Return mUnreadCount
End Sub

Public Sub GetUnreadList() As List
    Return mUnreadList
End Sub
