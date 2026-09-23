@echo off
rem pptx-open — abilita RemoteApp (RAIL) disabilitando la allowlist delle app
rem Terminal Server. Serve al seamless: `xfreerdp /app:program:...` lancia una
rem singola applicazione come finestra nativa. Richiede privilegi (HKLM).
setlocal EnableExtensions

set "K=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList"
reg add "%K%" /v fDisabled /t REG_DWORD /d 1 /f

echo [pptx-open] RemoteApp allowlist disabilitata
exit /b 0
