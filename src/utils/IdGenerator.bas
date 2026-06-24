'=============================================================================
' IdGenerator.bas — יצירת מזהים ייחודיים
' B4X Class Module
'
' כשאין גישה ל-Firebase Push Key (offline / pre-save), ניצור מזהה מקומי.
'=============================================================================
Sub Class_Globals
    Private mCounter As Long = 0
End Sub

Public Sub Initialize()
    mCounter = 0
End Sub

' UUID v4 בסגנון: "evt_a1b2c3d4e5f6"
Public Sub NewEventId() As String
    Return "evt_" & RandomHex(12)
End Sub

Public Sub NewTaskId() As String
    Return "task_" & RandomHex(12)
End Sub

Public Sub NewNotifId() As String
    Return "notif_" & RandomHex(10)
End Sub

Public Sub NewFamilyId() As String
    Return "fam_" & RandomHex(8)
End Sub

' מזהה מבוסס timestamp + counter (ממוין כרונולוגית)
Public Sub NewSortableId(prefix As String) As String
    mCounter = mCounter + 1
    Dim ts As String = Bit.ToHexString(DateTime.Now)
    Dim cnt As String = NumberFormat2(mCounter Mod 1000, 3, 0, 0, False)
    Return prefix & "_" & ts & "_" & cnt
End Sub

' מזהה לאירוע חוזר (templateId + תאריך)
Public Sub NewOccurrenceId(templateId As String, dateStr As String) As String
    Return templateId & "_" & dateStr.Replace("-", "")
End Sub

Private Sub RandomHex(length As Int) As String
    Dim sb As StringBuilder
    sb.Initialize
    Dim chars As String = "0123456789abcdef"
    For i = 1 To length
        Dim idx As Int = Rnd(0, 16)
        sb.Append(chars.SubString2(idx, idx + 1))
    Next
    Return sb.ToString
End Sub
