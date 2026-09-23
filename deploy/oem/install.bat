@echo off
rem pptx-open — provisioning OEM eseguito da dockur/windows alla fine
rem dell'installazione automatica. La cartella deploy/oem/ viene copiata in
rem C:\OEM. Vedi https://github.com/dockur/windows ("run a command after
rem installation").
setlocal EnableExtensions

echo [pptx-open] OEM provisioning start %DATE% %TIME%

rem --- Font di riferimento (Manrope) necessario al gate di fedelta' -------
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
if exist "C:\OEM\office\configuration.xml" (
  call "C:\OEM\office\install-office.bat"
  if errorlevel 1 echo [pptx-open] ATTENZIONE: installazione Office fallita
) else (
  echo [pptx-open] Office non configurato, salto l'installazione
)

rem --- Trusted location Z:\ e Protected View off --------------------------
call "C:\OEM\configure-trust.bat"

rem --- Niente blocco/sospensione sessione (serve al wrapper via tastiera) --
call "C:\OEM\configure-session.bat"

rem --- Report finale ------------------------------------------------------
if exist "%ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE" (
  echo [pptx-open] PowerPoint presente: %ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE
) else (
  echo [pptx-open] PowerPoint NON trovato dopo il provisioning
)

echo [pptx-open] OEM provisioning done > "C:\OEM\provisioned.txt"
echo [pptx-open] OEM provisioning done
endlocal
