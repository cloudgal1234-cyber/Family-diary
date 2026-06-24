'=============================================================================
' DateTimeUtils.bas — עזרי תאריך ושעה
' B4X Class Module (Static-style — Singleton)
'=============================================================================
Sub Class_Globals
    ' אין state — כל המתודות stateless
End Sub

Public Sub Initialize()
End Sub

'=============================================================================
' פורמט תצוגה
'=============================================================================

' Timestamp → "15:30"
Public Sub FormatTime(ts As Long) As String
    Dim old As String = DateTime.TimeFormat
    DateTime.TimeFormat = "HH:mm"
    Dim s As String = DateTime.Time(ts)
    DateTime.TimeFormat = old
    Return s
End Sub

' Timestamp → "יום שלישי, 15 בנובמבר"
Public Sub FormatDateHebrew(ts As Long) As String
    Dim dayName As String = GetHebrewDayName(ts)
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "d"
    Dim day As String = DateTime.Date(ts)
    DateTime.DateFormat = old
    Return dayName & ", " & day & " ב" & GetHebrewMonthName(ts)
End Sub

' Timestamp → "15 בנובמבר, 15:30"
Public Sub FormatDateTime(ts As Long) As String
    Return FormatDateHebrew(ts) & ", " & FormatTime(ts)
End Sub

' טווח שעות: "15:30 – 17:00"
Public Sub FormatTimeRange(startTs As Long, endTs As Long) As String
    Return FormatTime(startTs) & " – " & FormatTime(endTs)
End Sub

' כמה זמן נשאר עד לאירוע: "בעוד 2 שעות", "בעוד 30 דק'", "כבר התחיל"
Public Sub FormatTimeUntil(eventTs As Long) As String
    Dim diffMs As Long = eventTs - DateTime.Now
    If diffMs < 0 Then Return "כבר התחיל"
    Dim diffMin As Long = diffMs / 60000
    If diffMin < 60 Then Return "בעוד " & diffMin & " דק'"
    Dim diffHours As Long = diffMin / 60
    If diffHours < 24 Then Return "בעוד " & diffHours & " שע'"
    Dim diffDays As Long = diffHours / 24
    Return "בעוד " & diffDays & " ימים"
End Sub

'=============================================================================
' המרות
'=============================================================================

' "2024-11-15" → Timestamp UTC midnight
Public Sub DateStrToTs(dateStr As String) As Long
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim ts As Long = DateTime.DateParse(dateStr)
    DateTime.DateFormat = old
    Return ts
End Sub

' Timestamp → "2024-11-15"
Public Sub TsToDateStr(ts As Long) As String
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim s As String = DateTime.Date(ts)
    DateTime.DateFormat = old
    Return s
End Sub

' "15:30" + Timestamp של יום → Timestamp עם שעה מדויקת
Public Sub CombineDateAndTimeStr(dateTs As Long, timeStr As String) As Long
    Dim parts() As String = Regex.Split(":", timeStr)
    If parts.Length < 2 Then Return dateTs
    Dim hours As Int   = CInt(parts(0))
    Dim minutes As Int = CInt(parts(1))
    Dim midnight As Long = GetMidnight(dateTs)
    Return midnight + (hours * 3600000) + (minutes * 60000)
End Sub

' Timestamp → Timestamp של חצות באותו יום
Public Sub GetMidnight(ts As Long) As Long
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "yyyy-MM-dd"
    Dim dateStr As String = DateTime.Date(ts)
    Dim midnight As Long = DateStrToTs(dateStr)
    DateTime.DateFormat = old
    Return midnight
End Sub

' האם שני timestamps באותו יום?
Public Sub IsSameDay(ts1 As Long, ts2 As Long) As Boolean
    Return TsToDateStr(ts1) = TsToDateStr(ts2)
End Sub

' האם timestamp היום?
Public Sub IsToday(ts As Long) As Boolean
    Return IsSameDay(ts, DateTime.Now)
End Sub

'=============================================================================
' שמות בעברית
'=============================================================================

Public Sub GetHebrewDayName(ts As Long) As String
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "u"   ' 1=Mon ... 7=Sun
    Dim dayNum As Int = CInt(DateTime.Date(ts))
    DateTime.DateFormat = old

    Dim names() As String = Array As String("שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת", "ראשון")
    If dayNum >= 1 And dayNum <= 7 Then
        Return "יום " & names(dayNum - 1)
    End If
    Return ""
End Sub

Public Sub GetHebrewMonthName(ts As Long) As String
    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "M"
    Dim month As Int = CInt(DateTime.Date(ts))
    DateTime.DateFormat = old

    Dim names() As String = Array As String( _
        "ינואר", "פברואר", "מרץ", "אפריל", "מאי", "יוני", _
        "יולי", "אוגוסט", "ספטמבר", "אוקטובר", "נובמבר", "דצמבר")
    If month >= 1 And month <= 12 Then Return names(month - 1)
    Return ""
End Sub

' יצירת List של 7 תאריכים לשבוע (מיום שני של השבוע הנוכחי)
Public Sub GetCurrentWeekDates() As List
    Dim result As List
    result.Initialize

    Dim old As String = DateTime.DateFormat
    DateTime.DateFormat = "u"
    Dim todayDow As Int = CInt(DateTime.Date(DateTime.Now))   ' 1=Mon
    DateTime.DateFormat = old

    Dim mondayTs As Long = GetMidnight(DateTime.Now) - ((todayDow - 1) * 86400000)
    For i = 0 To 6
        result.Add(TsToDateStr(mondayTs + (i * 86400000)))
    Next

    Return result
End Sub
