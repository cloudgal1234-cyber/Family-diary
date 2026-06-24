'=============================================================================
' DatabaseManager.bas — שכבת נתונים: Firebase Realtime Database
' B4X Class Module
'
' תיאור: כל גישה ל-Firebase עוברת דרך כאן.
'         שאר הקוד לא יודע דבר על Firebase — הוא מדבר רק עם DatabaseManager.
'         זה מממש את עיקרון הפרדת אחריות (Separation of Concerns).
'
' ספריות נדרשות (B4A):
'   - FirebaseDatabase (B4A Firebase library)
'   - JSON (מובנית)
'
' אירועים שה-class מייצר (Events raised to caller):
'   - EventsLoaded(events As List)
'   - TasksLoaded(tasks As List)
'   - EventChanged(evt As CalendarEvent)
'   - TaskChanged(task As FamilyTask)
'   - NotificationReceived(notif As Map)
'   - Error(message As String)
'=============================================================================
Sub Class_Globals

    Private mFamilyId    As String
    Private mCurrentUser As FamilyUser

    ' Firebase Realtime Database references (B4A FirebaseDatabase library)
    Private mDB          As FirebaseDatabase
    Private mEventsRef   As DatabaseReference
    Private mTasksRef    As DatabaseReference
    Private mNotifsRef   As DatabaseReference

    ' מאזינים פעילים — כדי לנתקם בעת צורך
    Private mEventsListener   As ValueEventListener
    Private mTasksListener    As ValueEventListener

    ' Cache מקומי (אופציונלי — מונע בקשות חוזרות)
    Private mEventsCache As Map
    Private mTasksCache  As Map

    Private mEventObject As String  ' שם האובייקט שיקבל אירועים (events)

End Sub

'-----------------------------------------------------------------------------
' אתחול: חובה לקרוא לפני כל שימוש
'-----------------------------------------------------------------------------
Public Sub Initialize(familyId As String, currentUser As FamilyUser, eventObject As String)
    mFamilyId    = familyId
    mCurrentUser = currentUser
    mEventObject = eventObject

    mEventsCache.Initialize
    mTasksCache.Initialize

    mDB.Initialize2(GetFirebaseConfig())

    ' נתיבי Firebase
    mEventsRef = mDB.GetReference("families/" & familyId & "/events")
    mTasksRef  = mDB.GetReference("families/" & familyId & "/tasks")
    mNotifsRef = mDB.GetReference("families/" & familyId & "/notifications")
End Sub

'-----------------------------------------------------------------------------
' האזנה בזמן אמת לאירועים (Real-time listener)
' הפעלה פעם אחת — Firebase יעדכן אוטומטית בכל שינוי
'-----------------------------------------------------------------------------
Public Sub StartListeningToEvents()
    mEventsListener = mEventsRef.AddValueEventListener(mEventObject, "FirebaseEvents")
End Sub

Public Sub StopListeningToEvents()
    If mEventsListener.IsInitialized Then
        mEventsRef.RemoveEventListener(mEventsListener)
    End If
End Sub

' קריאה חוזרת: Firebase קרא — נתח ל-List של CalendarEvent
Sub FirebaseEvents_ValueChanged(snapshot As DataSnapshot)
    If snapshot.Exists = False Then
        RaiseEvent(mEventObject, "EventsLoaded", Array(CreateList()))
        Return
    End If

    Dim events As List
    events.Initialize

    Dim allData As Map = snapshot.Value
    For i = 0 To allData.Size - 1
        Dim rawMap As Map = allData.GetValueAt(i)
        Dim evt As CalendarEvent
        evt.Initialize
        evt.FromMap(rawMap)
        If evt.IsDeleted = False Then
            mEventsCache.Put(evt.Id, evt)
            events.Add(evt)
        End If
    Next

    RaiseEvent(mEventObject, "EventsLoaded", Array(events))
End Sub

Sub FirebaseEvents_Cancelled(error As DatabaseError)
    RaiseEvent(mEventObject, "Error", Array("שגיאת Firebase (Events): " & error.Message))
End Sub

'-----------------------------------------------------------------------------
' האזנה בזמן אמת למשימות
'-----------------------------------------------------------------------------
Public Sub StartListeningToTasks()
    mTasksListener = mTasksRef.AddValueEventListener(mEventObject, "FirebaseTasks")
End Sub

Public Sub StopListeningToTasks()
    If mTasksListener.IsInitialized Then
        mTasksRef.RemoveEventListener(mTasksListener)
    End If
End Sub

Sub FirebaseTasks_ValueChanged(snapshot As DataSnapshot)
    If snapshot.Exists = False Then
        RaiseEvent(mEventObject, "TasksLoaded", Array(CreateList()))
        Return
    End If

    Dim tasks As List
    tasks.Initialize

    Dim allData As Map = snapshot.Value
    For i = 0 To allData.Size - 1
        Dim rawMap As Map = allData.GetValueAt(i)
        Dim task As FamilyTask
        task.Initialize
        task.FromMap(rawMap)
        If task.IsDeleted = False Then
            mTasksCache.Put(task.Id, task)
            tasks.Add(task)
        End If
    Next

    RaiseEvent(mEventObject, "TasksLoaded", Array(tasks))
End Sub

Sub FirebaseTasks_Cancelled(error As DatabaseError)
    RaiseEvent(mEventObject, "Error", Array("שגיאת Firebase (Tasks): " & error.Message))
End Sub

'-----------------------------------------------------------------------------
' שמירת אירוע חדש / עדכון אירוע קיים
'-----------------------------------------------------------------------------
Public Sub SaveEvent(evt As CalendarEvent)
    evt.UpdatedBy = mCurrentUser.Id
    evt.UpdatedAt = DateTime.Now

    If evt.Id = "" Then
        evt.Id        = mEventsRef.Push.Key   ' מפתח ייחודי של Firebase
        evt.CreatedBy = mCurrentUser.Id
        evt.CreatedAt = DateTime.Now
    End If

    mEventsRef.Child(evt.Id).SetValue(evt.ToMap, mEventObject, "SaveEvent")
End Sub

Sub SaveEvent_Complete(success As Boolean)
    If success = False Then
        RaiseEvent(mEventObject, "Error", Array("שמירת אירוע נכשלה"))
    End If
End Sub

'-----------------------------------------------------------------------------
' Hot Update: עדכון סטטוס + זמן נוכחי (שינוי מהיר, ללא טעינה מחדש)
'-----------------------------------------------------------------------------
Public Sub UpdateEventStatus(eventId As String, newStatus As String, _
                              newStartTs As Long, newEndTs As Long, _
                              statusNote As String)
    Dim updates As Map
    updates.Initialize
    updates.Put("status",             newStatus)
    updates.Put("status_note",        statusNote)
    updates.Put("updated_by",         mCurrentUser.Id)
    updates.Put("updated_at",         DateTime.Now)

    ' עדכון זמן נוכחי בלבד — הזמן המקורי נשמר ל-audit trail
    Dim currentTime As Map
    currentTime.Initialize
    currentTime.Put("start", newStartTs)
    currentTime.Put("end",   newEndTs)
    updates.Put("current_time", currentTime)

    mEventsRef.Child(eventId).UpdateChildren(updates, mEventObject, "HotUpdate")

    ' שלח התראה לשאר בני המשפחה
    SendStatusNotification(eventId, newStatus, statusNote)
End Sub

Sub HotUpdate_Complete(success As Boolean)
    If success = False Then
        RaiseEvent(mEventObject, "Error", Array("עדכון סטטוס נכשל"))
    End If
End Sub

'-----------------------------------------------------------------------------
' מחיקה רכה (Soft Delete) — לא מוחקים מ-Firebase, רק מסמנים
'-----------------------------------------------------------------------------
Public Sub DeleteEvent(eventId As String)
    Dim updates As Map
    updates.Initialize
    updates.Put("is_deleted", True)
    updates.Put("updated_by", mCurrentUser.Id)
    updates.Put("updated_at", DateTime.Now)
    mEventsRef.Child(eventId).UpdateChildren(updates, mEventObject, "DeleteEvent")
End Sub

Sub DeleteEvent_Complete(success As Boolean)
    If success = False Then
        RaiseEvent(mEventObject, "Error", Array("מחיקת אירוע נכשלה"))
    End If
End Sub

'-----------------------------------------------------------------------------
' שמירת משימה
'-----------------------------------------------------------------------------
Public Sub SaveTask(task As FamilyTask)
    task.UpdatedBy = mCurrentUser.Id
    task.UpdatedAt = DateTime.Now

    If task.Id = "" Then
        task.Id        = mTasksRef.Push.Key
        task.CreatedBy = mCurrentUser.Id
        task.CreatedAt = DateTime.Now
    End If

    mTasksRef.Child(task.Id).SetValue(task.ToMap, mEventObject, "SaveTask")
End Sub

Sub SaveTask_Complete(success As Boolean)
    If success = False Then
        RaiseEvent(mEventObject, "Error", Array("שמירת משימה נכשלה"))
    End If
End Sub

'-----------------------------------------------------------------------------
' סימון משימה כהושלמה
'-----------------------------------------------------------------------------
Public Sub ToggleTaskDone(taskId As String, isDone As Boolean)
    Dim updates As Map
    updates.Initialize

    If isDone Then
        updates.Put("status",       "DONE")
        updates.Put("completed_at", DateTime.Now)
    Else
        updates.Put("status",       "PENDING")
        updates.Put("completed_at", 0)
    End If

    updates.Put("updated_by", mCurrentUser.Id)
    updates.Put("updated_at", DateTime.Now)

    mTasksRef.Child(taskId).UpdateChildren(updates, mEventObject, "ToggleTask")
End Sub

Sub ToggleTask_Complete(success As Boolean)
    If success = False Then
        RaiseEvent(mEventObject, "Error", Array("עדכון משימה נכשל"))
    End If
End Sub

'-----------------------------------------------------------------------------
' שליחת התראה לבני המשפחה
'-----------------------------------------------------------------------------
Private Sub SendStatusNotification(eventId As String, status As String, note As String)
    Dim notifRef As DatabaseReference = mNotifsRef.Push

    Dim notif As Map
    notif.Initialize
    notif.Put("id",         notifRef.Key)
    notif.Put("type",       "EVENT_" & status)
    notif.Put("ref_id",     eventId)
    notif.Put("ref_type",   "EVENT")
    notif.Put("message",    BuildNotifMessage(status, note))
    notif.Put("created_by", mCurrentUser.Id)
    notif.Put("created_at", DateTime.Now)
    notif.Put("is_urgent",  status = "CANCELED" Or status = "MOVED")

    Dim readBy As Map
    readBy.Initialize
    readBy.Put(mCurrentUser.Id, DateTime.Now)   ' שולח כבר "קרא"
    notif.Put("read_by", readBy)

    notifRef.SetValue(notif, mEventObject, "SendNotif")
End Sub

Sub SendNotif_Complete(success As Boolean)
    ' שקט — התראות הן best-effort
End Sub

Private Sub BuildNotifMessage(status As String, note As String) As String
    Select Case status
        Case "MOVED"       : Return "האירוע הוזז — " & note
        Case "CANCELED"    : Return "האירוע בוטל — " & note
        Case "RESCHEDULED" : Return "האירוע נקבע מחדש — " & note
        Case "POSTPONED"   : Return "האירוע נדחה — " & note
        Case Else          : Return note
    End Select
End Sub

'-----------------------------------------------------------------------------
' Cache queries (גישה מהירה ללא Firebase roundtrip)
'-----------------------------------------------------------------------------
Public Sub GetCachedEvent(eventId As String) As CalendarEvent
    If mEventsCache.ContainsKey(eventId) Then Return mEventsCache.Get(eventId)
    Dim empty As CalendarEvent
    empty.Initialize
    Return empty
End Sub

Public Sub GetCachedEventsByDate(dateStr As String) As List
    Dim result As List
    result.Initialize
    For i = 0 To mEventsCache.Size - 1
        Dim evt As CalendarEvent = mEventsCache.GetValueAt(i)
        If evt.DateStr = dateStr Then result.Add(evt)
    Next
    Return result
End Sub

'-----------------------------------------------------------------------------
' קונפיגורציה של Firebase (מלא בנתוני הפרויקט שלך)
'-----------------------------------------------------------------------------
Private Sub GetFirebaseConfig() As Map
    Dim config As Map
    config.Initialize
    config.Put("apiKey",            "YOUR_API_KEY")
    config.Put("authDomain",        "YOUR_PROJECT.firebaseapp.com")
    config.Put("databaseURL",       "https://YOUR_PROJECT-default-rtdb.firebaseio.com")
    config.Put("projectId",         "YOUR_PROJECT_ID")
    config.Put("storageBucket",     "YOUR_PROJECT.appspot.com")
    config.Put("messagingSenderId", "YOUR_SENDER_ID")
    config.Put("appId",             "YOUR_APP_ID")
    Return config
End Sub

'-----------------------------------------------------------------------------
' ניקוי
'-----------------------------------------------------------------------------
Public Sub Cleanup()
    StopListeningToEvents
    StopListeningToTasks
    mEventsCache.Initialize
    mTasksCache.Initialize
End Sub

Private Sub CreateList() As List
    Dim l As List
    l.Initialize
    Return l
End Sub
