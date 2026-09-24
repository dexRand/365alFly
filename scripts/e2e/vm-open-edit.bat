@echo off
rem e2e "explode" (Task 10) — helper in-VM usato al posto di
rem wrapper/vm/open-file.bat da scripts/e2e-explode.sh. Apre/modifica/salva/
rem chiude il file (Z:\request.txt) via PowerPoint COM e segnala Z:\done.txt.
setlocal EnableExtensions

del "Z:\done.txt" >nul 2>&1

set "REL="
set /p REL=<"Z:\request.txt"
if not defined REL ( echo error:request> "Z:\done.txt" & exit /b 1 )

rem Evita di agganciare un'istanza PowerPoint già aperta.
taskkill /im POWERPNT.EXE /f >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\e2e-edit.ps1" "%REL%" > "Z:\e2e-out.txt" 2>&1
exit /b 0
