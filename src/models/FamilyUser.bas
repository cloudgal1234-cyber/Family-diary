'=============================================================================
' FamilyUser.bas — מודל משתמש במשפחה
' B4X Class Module
'=============================================================================
Sub Class_Globals

    Public Id          As String   ' Firebase Auth UID
    Public FamilyId    As String
    Public Name        As String   ' "יעל", "אמא"
    Public Role        As String   ' ROLE_PARENT / ROLE_CHILD
    Public ColorHex    As String   ' צבע ייחודי למשתמש בתצוגת לוח שנה
    Public AvatarUrl   As String
    Public FcmToken    As String   ' לשליחת Push Notifications
    Public LastSeen    As Long

    Public NotificationsEnabled      As Boolean
    Public DefaultReminderMinutes    As Int

End Sub

Public Sub Initialize()
    Id                       = ""
    FamilyId                 = ""
    Name                     = ""
    Role                     = ROLE_CHILD
    ColorHex                 = "#4ECDC4"
    AvatarUrl                = ""
    FcmToken                 = ""
    LastSeen                 = 0
    NotificationsEnabled     = True
    DefaultReminderMinutes   = 30
End Sub

Public Sub FromMap(m As Map)
    If m.IsInitialized = False Then Return
    Id        = MapGetStr(m, "id", "")
    FamilyId  = MapGetStr(m, "family_id", "")
    Name      = MapGetStr(m, "name", "")
    Role      = MapGetStr(m, "role", ROLE_CHILD)
    ColorHex  = MapGetStr(m, "color", "#4ECDC4")
    AvatarUrl = MapGetStr(m, "avatar_url", "")
    FcmToken  = MapGetStr(m, "fcm_token", "")
    LastSeen  = MapGetLong(m, "last_seen", 0)
    If m.ContainsKey("settings") Then
        Dim s As Map = m.Get("settings")
        NotificationsEnabled   = MapGetBool(s, "notifications_enabled", True)
        DefaultReminderMinutes = MapGetInt(s, "default_reminder_minutes", 30)
    End If
End Sub

Public Sub ToMap() As Map
    Dim m As Map
    m.Initialize
    m.Put("id",        Id)
    m.Put("family_id", FamilyId)
    m.Put("name",      Name)
    m.Put("role",      Role)
    m.Put("color",     ColorHex)
    m.Put("avatar_url",AvatarUrl)
    m.Put("fcm_token", FcmToken)
    m.Put("last_seen", LastSeen)
    Dim s As Map
    s.Initialize
    s.Put("notifications_enabled",     NotificationsEnabled)
    s.Put("default_reminder_minutes",  DefaultReminderMinutes)
    m.Put("settings", s)
    Return m
End Sub

Public Sub IsParent() As Boolean
    Return Role = ROLE_PARENT
End Sub

Public Sub ROLE_PARENT() As String : Return "PARENT" : End Sub
Public Sub ROLE_CHILD()  As String : Return "CHILD"  : End Sub

Private Sub MapGetStr(m As Map, key As String, defaultVal As String) As String
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub
Private Sub MapGetBool(m As Map, key As String, defaultVal As Boolean) As Boolean
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub
Private Sub MapGetLong(m As Map, key As String, defaultVal As Long) As Long
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub
Private Sub MapGetInt(m As Map, key As String, defaultVal As Int) As Int
    If m.ContainsKey(key) And m.Get(key) <> Null Then Return m.Get(key)
    Return defaultVal
End Sub
