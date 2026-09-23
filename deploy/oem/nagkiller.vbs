' pptx-open - chiude automaticamente la finestra "Sign in to set up Office"
' che Office non attivato mostra a ogni avvio. NON e' attivazione: e' solo
' auto-dismiss del prompt, cosi' PowerPoint apre il documento senza account.
Option Explicit
Dim sh
Set sh = CreateObject("WScript.Shell")
Do
  On Error Resume Next
  If sh.AppActivate("Sign in to set up Office") Then
    WScript.Sleep 150
    sh.SendKeys "{ESC}"
    WScript.Sleep 300
  End If
  On Error GoTo 0
  WScript.Sleep 1200
Loop
