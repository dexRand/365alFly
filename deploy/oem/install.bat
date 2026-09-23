@echo off
rem pptx-open — provisioning OEM eseguito da dockur/windows alla fine
rem dell'installazione automatica. La cartella deploy/oem/ viene copiata in
rem C:\OEM. Vedi https://github.com/dockur/windows ("run a command after
rem installation").
setlocal EnableExtensions

rem --- Barra di stato visibile nella VM (VNC) -----------------------------
set "STATUS=C:\OEM\status.txt"
>"%STATUS%" echo -1 Avvio provisioning...
if exist "C:\OEM\status-gui.ps1" start "" powershell -NoProfile -ExecutionPolicy Bypass -File "C:\OEM\status-gui.ps1"

echo [pptx-open] OEM provisioning start %DATE% %TIME%

rem --- Font di riferimento (Manrope) necessario al gate di fedelta' -------
>"%STATUS%" echo -1 Installazione dei font...
set "FONT_DIR=C:\OEM\fonts"
if not exist "%FONT_DIR%" set "FONT_DIR=Z:\fonts"
dir /b "%FONT_DIR%\*.ttf" >nul 2>&1
if errorlevel 1 (
  echo [pptx-open] Nessun font da installare in %FONT_DIR%, salto
) else (
  echo [pptx-open] Installazione font da %FONT_DIR%
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$shell = New-Object -ComObject Shell.Application; $fonts = $shell.Namespace(0x14); Get-ChildItem -Path '%FONT_DIR%\*.ttf' | ForEach-Object { $fonts.CopyHere($_.FullName, 0x10) }"
)

rem --- Office (solo se il config generato esiste) --------------------------
>"%STATUS%" echo -1 Installazione Office (10-20 min, download dal CDN Microsoft)...
if exist "C:\OEM\office\configuration.xml" (
  call "C:\OEM\office\install-office.bat"
  if errorlevel 1 echo [pptx-open] ATTENZIONE: installazione Office fallita
) else (
  echo [pptx-open] Office non configurato, salto l'installazione
)

rem --- Trusted location Z:\ e Protected View off --------------------------
>"%STATUS%" echo 85 Configurazione (trusted folder, sessione, prompt)...
call "C:\OEM\configure-trust.bat"

rem --- Niente blocco/sospensione sessione (serve al wrapper via tastiera) --
call "C:\OEM\configure-session.bat"

rem --- RemoteApp/RAIL: disabilita allowlist app (seamless) ------------------
call "C:\OEM\configure-remoteapp.bat"

rem --- Sopprime il prompt di primo avvio/sign-in di Office -----------------
call "C:\OEM\configure-office.bat"

rem --- Chiude da solo "Sign in to set up Office" (NON e' attivazione) -------
set "NAGK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\nagkiller.vbs"
copy /y "C:\OEM\nagkiller.vbs" "%NAGK%" >nul 2>&1
start "" wscript //B "%NAGK%"
rem ridondanza: avvialo anche a ogni logon via chiave Run
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v pptxNagKiller /t REG_SZ /d "wscript.exe //B C:\OEM\nagkiller.vbs" /f >nul 2>&1

rem --- Report finale ------------------------------------------------------
if exist "%ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE" (
  echo [pptx-open] PowerPoint presente: %ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE
) else (
  echo [pptx-open] PowerPoint NON trovato dopo il provisioning
)

echo [pptx-open] OEM provisioning done > "C:\OEM\provisioned.txt"
>"%STATUS%" echo 100 Fatto. PowerPoint pronto.
echo [pptx-open] OEM provisioning done
endlocal
