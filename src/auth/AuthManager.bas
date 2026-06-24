'=============================================================================
' AuthManager.bas — ניהול כניסה עם Firebase Authentication
' B4X Class Module
'
' תיאור: מטפל בכניסה / יציאה / רישום עם Google Sign-In ואימייל+סיסמה.
'         שומר את פרטי המשתמש ב-SharedPreferences לכניסה אוטומטית.
'
' ספריות נדרשות (B4A):
'   - FirebaseAuth
'   - GoogleSignIn (com.google.android.gms:play-services-auth)
'   - SharedPreferences (מובנית)
'
' אירועים:
'   - SignInSuccess(user As FamilyUser)
'   - SignInFailed(error As String)
'   - SignedOut
'   - FamilyJoined(familyId As String)
'=============================================================================
Sub Class_Globals

    Private mAuth        As FirebaseAuth
    Private mPrefs       As SharedPreferences
    Private mEventObject As String
    Private mConfig      As AppConfig

    Private mCurrentUser As FamilyUser
    Private mIsSignedIn  As Boolean

    Private DB_KEY_USER_ID    As String = "auth_user_id"
    Private DB_KEY_FAMILY_ID  As String = "auth_family_id"
    Private DB_KEY_USER_NAME  As String = "auth_user_name"
    Private DB_KEY_USER_ROLE  As String = "auth_user_role"
    Private DB_KEY_USER_COLOR As String = "auth_user_color"

End Sub

Public Sub Initialize(config As AppConfig, eventObject As String)
    mConfig      = config
    mEventObject = eventObject
    mAuth.Initialize(config.GetFirebaseConfig())
    mPrefs.Initialize("FamilyDiaryPrefs", False)
    mIsSignedIn = False
    mCurrentUser.Initialize
End Sub

'-----------------------------------------------------------------------------
' בדיקת כניסה אוטומטית בהפעלת האפליקציה
'-----------------------------------------------------------------------------
Public Sub TryAutoSignIn() As Boolean
    ' Firebase שומר טוקן — בדוק אם יש משתמש פעיל
    If mAuth.CurrentUser <> Null Then
        LoadUserFromPrefs
        mIsSignedIn = True
        RaiseEvent(mEventObject, "SignInSuccess", Array(mCurrentUser))
        Return True
    End If
    Return False
End Sub

'-----------------------------------------------------------------------------
' כניסה עם Google
'-----------------------------------------------------------------------------
Public Sub SignInWithGoogle(activity As Object)
    Dim googleClient As GoogleSignInClient
    Dim options As GoogleSignInOptions
    options.Initialize(GoogleSignInOptions.DEFAULT_SIGN_IN)
    options.RequestIdToken(mConfig.FIREBASE_APP_ID)
    options.RequestEmail
    googleClient.Initialize(activity, options)
    googleClient.SignIn(activity, mEventObject, "GoogleSignIn")
End Sub

Sub GoogleSignIn_Result(idToken As String, email As String, displayName As String)
    If idToken = "" Then
        RaiseEvent(mEventObject, "SignInFailed", Array("כניסה עם Google נכשלה"))
        Return
    End If
    Dim credential As AuthCredential = GoogleAuthProvider.GetCredential(idToken)
    mAuth.SignInWithCredential(credential, mEventObject, "FirebaseSignIn")
End Sub

'-----------------------------------------------------------------------------
' כניסה עם אימייל+סיסמה
'-----------------------------------------------------------------------------
Public Sub SignInWithEmail(email As String, password As String)
    If email = "" Or password = "" Then
        RaiseEvent(mEventObject, "SignInFailed", Array("יש למלא אימייל וסיסמה"))
        Return
    End If
    mAuth.SignInWithEmailAndPassword(email, password, mEventObject, "FirebaseSignIn")
End Sub

Public Sub RegisterWithEmail(email As String, password As String, name As String)
    If email = "" Or password.Length < 6 Then
        RaiseEvent(mEventObject, "SignInFailed", Array("הסיסמה חייבת להכיל לפחות 6 תווים"))
        Return
    End If
    mAuth.CreateUserWithEmailAndPassword(email, password, mEventObject, "FirebaseRegister")
End Sub

Sub FirebaseRegister_Complete(user As FirebaseUser, errorMessage As String)
    If user = Null Then
        RaiseEvent(mEventObject, "SignInFailed", Array("הרשמה נכשלה: " & errorMessage))
        Return
    End If
    ' לאחר הרשמה → כניסה אוטומטית
    FirebaseSignIn_Complete(user, "")
End Sub

'-----------------------------------------------------------------------------
' Firebase אישר כניסה
'-----------------------------------------------------------------------------
Sub FirebaseSignIn_Complete(user As FirebaseUser, errorMessage As String)
    If user = Null Then
        RaiseEvent(mEventObject, "SignInFailed", Array("כניסה נכשלה: " & errorMessage))
        Return
    End If

    mCurrentUser.Initialize
    mCurrentUser.Id       = user.Uid
    mCurrentUser.Name     = IIf(user.DisplayName <> "", user.DisplayName, "משתמש")
    mCurrentUser.AvatarUrl = user.PhotoUrl
    mIsSignedIn           = True

    SaveUserToPrefs
    RaiseEvent(mEventObject, "SignInSuccess", Array(mCurrentUser))
End Sub

'-----------------------------------------------------------------------------
' יציאה
'-----------------------------------------------------------------------------
Public Sub SignOut()
    mAuth.SignOut
    mPrefs.Remove(DB_KEY_USER_ID)
    mPrefs.Remove(DB_KEY_FAMILY_ID)
    mIsSignedIn = False
    mCurrentUser.Initialize
    RaiseEvent(mEventObject, "SignedOut", Null)
End Sub

'-----------------------------------------------------------------------------
' שמירת/טעינת פרטים מקומיים
'-----------------------------------------------------------------------------
Private Sub SaveUserToPrefs()
    mPrefs.PutString(DB_KEY_USER_ID,    mCurrentUser.Id)
    mPrefs.PutString(DB_KEY_FAMILY_ID,  mCurrentUser.FamilyId)
    mPrefs.PutString(DB_KEY_USER_NAME,  mCurrentUser.Name)
    mPrefs.PutString(DB_KEY_USER_ROLE,  mCurrentUser.Role)
    mPrefs.PutString(DB_KEY_USER_COLOR, mCurrentUser.ColorHex)
End Sub

Private Sub LoadUserFromPrefs()
    mCurrentUser.Initialize
    mCurrentUser.Id       = mPrefs.GetString(DB_KEY_USER_ID, "")
    mCurrentUser.FamilyId = mPrefs.GetString(DB_KEY_FAMILY_ID, "")
    mCurrentUser.Name     = mPrefs.GetString(DB_KEY_USER_NAME, "")
    mCurrentUser.Role     = mPrefs.GetString(DB_KEY_USER_ROLE, "CHILD")
    mCurrentUser.ColorHex = mPrefs.GetString(DB_KEY_USER_COLOR, "#4ECDC4")
End Sub

'-----------------------------------------------------------------------------
' שיוך משתמש למשפחה (אחרי כניסה ראשונה)
'-----------------------------------------------------------------------------
Public Sub JoinFamily(familyId As String, role As String)
    mCurrentUser.FamilyId = familyId
    mCurrentUser.Role     = role
    SaveUserToPrefs
    RaiseEvent(mEventObject, "FamilyJoined", Array(familyId))
End Sub

Public Sub CreateNewFamily(familyName As String)
    ' יוצר familyId חדש ב-Firebase, מצרף את המשתמש כהורה
    Dim newId As String = "family_" & mCurrentUser.Id.SubString2(0, 8)
    mCurrentUser.FamilyId = newId
    mCurrentUser.Role     = "PARENT"
    SaveUserToPrefs
    RaiseEvent(mEventObject, "FamilyJoined", Array(newId))
End Sub

Public Sub GetCurrentUser() As FamilyUser
    Return mCurrentUser
End Sub

Public Sub IsSignedIn() As Boolean
    Return mIsSignedIn
End Sub

Private Function IIf(condition As Boolean, trueVal As Object, falseVal As Object) As Object
    If condition Then Return trueVal
    Return falseVal
End Function
