'=============================================================================
' FCMManager.bas — Firebase Cloud Messaging (Push Notifications)
' B4X Class Module
'
' תיאור: שולח ומקבל Push Notifications כשאירוע מוזז / בוטל.
'         פועל גם כשהאפליקציה ברקע.
'
' ספריות נדרשות:
'   - FirebaseMessaging (B4A Firebase Bundle)
'
' אירועים:
'   - PushReceived(title As String, body As String, data As Map)
'=============================================================================
Sub Class_Globals

    Private mMessaging   As FirebaseMessaging
    Private mEventObject As String
    Private mFamilyId    As String
    Private mUserId      As String

    ' FCM Server Key — לשמור ב-Firebase Functions, לא ב-Client!
    ' כאן הוא placeholder בלבד — שליחה מ-Cloud Functions
    Private FCM_SERVER_KEY As String = "SERVER_KEY_IN_CLOUD_FUNCTIONS_ONLY"

End Sub

Public Sub Initialize(familyId As String, userId As String, eventObject As String)
    mFamilyId    = familyId
    mUserId      = userId
    mEventObject = eventObject
    mMessaging.Initialize(mEventObject, "FCM")
End Sub

'-----------------------------------------------------------------------------
' רישום ל-Topic של המשפחה (כל בני המשפחה מקבלים)
'-----------------------------------------------------------------------------
Public Sub SubscribeToFamilyTopic()
    mMessaging.SubscribeToTopic("family_" & mFamilyId)
    mMessaging.SubscribeToTopic("user_" & mUserId)   ' התראות אישיות
End Sub

Public Sub UnsubscribeFromFamilyTopic()
    mMessaging.UnsubscribeFromTopic("family_" & mFamilyId)
    mMessaging.UnsubscribeFromTopic("user_" & mUserId)
End Sub

' קבל את ה-Token הנוכחי ושמור ב-Firebase
Public Sub RefreshToken()
    mMessaging.GetToken(mEventObject, "TokenRefresh")
End Sub

Sub TokenRefresh_Complete(token As String)
    If token = "" Then Return
    ' שמור token ב-Firebase לשליחה עתידית
    Log("FCM Token: " & token)
End Sub

'-----------------------------------------------------------------------------
' קבלת Notification בזמן שהאפליקציה פתוחה
'-----------------------------------------------------------------------------
Sub FCM_MessageReceived(title As String, body As String, data As Map)
    RaiseEvent(mEventObject, "PushReceived", Array(title, body, data))
End Sub

'-----------------------------------------------------------------------------
' בניית Payload לשליחה מ-Cloud Function
' (הפונקציה הזו מסביר את המבנה — הקריאה האמיתית מ-Firebase Functions)
'-----------------------------------------------------------------------------
Public Sub BuildEventMovedPayload(eventTitle As String, newTime As String, note As String) As Map
    Dim payload As Map
    payload.Initialize

    Dim notification As Map
    notification.Initialize
    notification.Put("title", "📅 " & eventTitle & " הוזז")
    notification.Put("body",  "עכשיו ב-" & newTime & IIf(note <> "", " — " & note, ""))
    notification.Put("sound", "default")
    notification.Put("badge", "1")
    payload.Put("notification", notification)

    Dim android As Map
    android.Initialize
    android.Put("priority", "high")
    Dim androidNotif As Map
    androidNotif.Initialize
    androidNotif.Put("channel_id", "hot_updates")
    androidNotif.Put("color",      "#F39C12")
    androidNotif.Put("icon",       "ic_event_moved")
    android.Put("notification", androidNotif)
    payload.Put("android", android)

    Dim apns As Map
    apns.Initialize
    Dim apnsPayload As Map
    apnsPayload.Initialize
    Dim aps As Map
    aps.Initialize
    aps.Put("sound", "default")
    aps.Put("badge", 1)
    apnsPayload.Put("aps", aps)
    apns.Put("payload", apnsPayload)
    payload.Put("apns", apns)

    Dim data As Map
    data.Initialize
    data.Put("type",      "EVENT_MOVED")
    data.Put("family_id", mFamilyId)
    payload.Put("data", data)

    Return payload
End Sub

Public Sub BuildEventCanceledPayload(eventTitle As String, reason As String) As Map
    Dim payload As Map
    payload.Initialize

    Dim notification As Map
    notification.Initialize
    notification.Put("title", "❌ " & eventTitle & " בוטל")
    notification.Put("body",  IIf(reason <> "", reason, "האירוע בוטל"))
    notification.Put("sound", "default")
    payload.Put("notification", notification)

    Dim data As Map
    data.Initialize
    data.Put("type",      "EVENT_CANCELED")
    data.Put("family_id", mFamilyId)
    payload.Put("data", data)

    Return payload
End Sub

Private Function IIf(condition As Boolean, trueVal As String, falseVal As String) As String
    If condition Then Return trueVal
    Return falseVal
End Function
