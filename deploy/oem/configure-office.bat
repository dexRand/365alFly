@echo off
rem pptx-open — disattiva l'esperienza di primo avvio ("Sign in to get started").
rem NON e' attivazione: e' solo la soppressione del prompt di onboarding, cosi'
rem PowerPoint apre direttamente il documento (resta il banner PRODUCT NOTICE).
setlocal EnableExtensions

set "G=HKCU\Software\Microsoft\Office\16.0\Common\General"
set "F=HKCU\Software\Microsoft\Office\16.0\FirstRun"

reg add "%G%" /v ShownFirstRunOptin /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%G%" /v ShownFileFmtPrompt /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%G%" /v ShownOptIn /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%G%" /v ShownSignIn /t REG_DWORD /d 1 /f >nul 2>&1

reg add "%F%" /v BootedRTM /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%F%" /v ShownFirstRun /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%F%" /v DisableMovie /t REG_DWORD /d 1 /f >nul 2>&1

echo [pptx-open] prompt di primo avvio/sign-in di Office soppressi
exit /b 0
