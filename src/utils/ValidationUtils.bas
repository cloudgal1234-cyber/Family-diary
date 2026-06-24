'=============================================================================
' ValidationUtils.bas — ולידציה ובדיקות קלט
' B4X Class Module
'=============================================================================
Sub Class_Globals
End Sub

Public Sub Initialize()
End Sub

' בדיקת אימייל תקני
Public Sub IsValidEmail(email As String) As Boolean
    If email = "" Then Return False
    Return Regex.IsMatch("[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}", email)
End Sub

' בדיקת סיסמה (מינימום 6 תווים)
Public Sub IsValidPassword(password As String) As Boolean
    Return password.Length >= 6
End Sub

' בדיקת כותרת אירוע
Public Sub IsValidEventTitle(title As String) As Boolean
    Dim t As String = title.Trim
    Return t.Length >= 1 And t.Length <= 120
End Sub

' בדיקת טווח שעות (שעת סיום אחרי שעת התחלה)
Public Sub IsValidTimeRange(startTs As Long, endTs As Long) As Boolean
    Return endTs > startTs
End Sub

' בדיקת תאריך עתידי
Public Sub IsFutureDate(ts As Long) As Boolean
    Return ts > DateTime.Now
End Sub

' ניקוי טקסט — הסרת רווחים כפולים
Public Sub CleanText(text As String) As String
    Dim cleaned As String = text.Trim
    Do While cleaned.Contains("  ")
        cleaned = cleaned.Replace("  ", " ")
    Loop
    Return cleaned
End Sub

' וידוא שמזהה Firebase תקין (אין תווים אסורים)
Public Sub IsValidFirebaseKey(key As String) As Boolean
    If key = "" Then Return False
    Return Regex.IsMatch("[^.#$\\[\\]]+", key)
End Sub

' המרת מספר טלפון לפורמט ישראלי
Public Sub NormalizeIsraeliPhone(phone As String) As String
    Dim p As String = phone.Replace("-", "").Replace(" ", "")
    If p.StartsWith("0") Then p = "+972" & p.SubString(1)
    Return p
End Sub

' בדיקת שדות חובה ב-Map
Public Sub HasRequiredFields(m As Map, fields() As String) As Boolean
    For i = 0 To fields.Length - 1
        If m.ContainsKey(fields(i)) = False Then Return False
        If m.Get(fields(i)) = Null Then Return False
        If m.Get(fields(i)) = "" Then Return False
    Next
    Return True
End Sub
