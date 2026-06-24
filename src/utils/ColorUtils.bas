'=============================================================================
' ColorUtils.bas — ניהול צבעים ואפקטים ויזואליים
' B4X Class Module
'=============================================================================
Sub Class_Globals
End Sub

Public Sub Initialize()
End Sub

' hex string → ARGB Int
Public Sub HexToInt(hex As String) As Int
    Dim h As String = hex.Replace("#", "")
    If h.Length = 6 Then h = "FF" & h
    Return Bit.ParseInt(h, 16)
End Sub

' ARGB Int → hex string (ללא #)
Public Sub IntToHex(color As Int) As String
    Return NumberFormat2(color, 8, 0, 0, False)
End Sub

' שנה שקיפות: alpha 0-255
Public Sub WithAlpha(color As Int, alpha As Int) As Int
    Return Bit.Or(Bit.ShiftLeft(alpha, 24), Bit.And(color, 0x00FFFFFF))
End Sub

' הכהה צבע ב-amount אחוזים (0-100)
Public Sub Darken(color As Int, amount As Int) As Int
    Dim r As Int = Bit.And(Bit.ShiftRight(color, 16), 0xFF)
    Dim g As Int = Bit.And(Bit.ShiftRight(color, 8),  0xFF)
    Dim b As Int = Bit.And(color, 0xFF)
    Dim factor As Float = 1 - (amount / 100)
    r = Max(0, CInt(r * factor))
    g = Max(0, CInt(g * factor))
    b = Max(0, CInt(b * factor))
    Return Bit.Or(0xFF000000, Bit.Or(Bit.ShiftLeft(r, 16), Bit.Or(Bit.ShiftLeft(g, 8), b)))
End Sub

' הבהר צבע ב-amount אחוזים (0-100)
Public Sub Lighten(color As Int, amount As Int) As Int
    Dim r As Int = Bit.And(Bit.ShiftRight(color, 16), 0xFF)
    Dim g As Int = Bit.And(Bit.ShiftRight(color, 8),  0xFF)
    Dim b As Int = Bit.And(color, 0xFF)
    Dim factor As Float = amount / 100
    r = Min(255, CInt(r + (255 - r) * factor))
    g = Min(255, CInt(g + (255 - g) * factor))
    b = Min(255, CInt(b + (255 - b) * factor))
    Return Bit.Or(0xFF000000, Bit.Or(Bit.ShiftLeft(r, 16), Bit.Or(Bit.ShiftLeft(g, 8), b)))
End Sub

' האם הצבע כהה? (לבחירת טקסט לבן/שחור)
Public Sub IsDark(color As Int) As Boolean
    Dim r As Int = Bit.And(Bit.ShiftRight(color, 16), 0xFF)
    Dim g As Int = Bit.And(Bit.ShiftRight(color, 8),  0xFF)
    Dim b As Int = Bit.And(color, 0xFF)
    ' Luminance לפי W3C
    Dim lum As Float = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    Return lum < 0.5
End Sub

' קבל צבע טקסט אוטומטי לפי רקע
Public Sub GetTextColorFor(backgroundColor As Int) As Int
    If IsDark(backgroundColor) Then Return 0xFFFFFFFF
    Return 0xFF212121
End Sub

' interpolate בין שני צבעים (t: 0.0 עד 1.0)
Public Sub Lerp(colorA As Int, colorB As Int, t As Float) As Int
    Dim rA As Int = Bit.And(Bit.ShiftRight(colorA, 16), 0xFF)
    Dim gA As Int = Bit.And(Bit.ShiftRight(colorA, 8),  0xFF)
    Dim bA As Int = Bit.And(colorA, 0xFF)
    Dim rB As Int = Bit.And(Bit.ShiftRight(colorB, 16), 0xFF)
    Dim gB As Int = Bit.And(Bit.ShiftRight(colorB, 8),  0xFF)
    Dim bB As Int = Bit.And(colorB, 0xFF)
    Dim r  As Int = CInt(rA + (rB - rA) * t)
    Dim g  As Int = CInt(gA + (gB - gA) * t)
    Dim b  As Int = CInt(bA + (bB - bA) * t)
    Return Bit.Or(0xFF000000, Bit.Or(Bit.ShiftLeft(r, 16), Bit.Or(Bit.ShiftLeft(g, 8), b)))
End Sub

Private Sub Max(a As Int, b As Int) As Int
    If a > b Then Return a
    Return b
End Sub

Private Sub Min(a As Int, b As Int) As Int
    If a < b Then Return a
    Return b
End Sub
