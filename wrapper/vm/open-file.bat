@echo off
rem pptx-open — helper DENTRO la VM. Apre il file indicato in Z:\request.txt
rem con PowerPoint, attende la chiusura e scrive Z:\done.txt per il wrapper.
rem Viene copiato sull'host da wrapper/pptx-open nella cartella condivisa.
setlocal EnableExtensions

set "PP="
if exist "%ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE" set "PP=%ProgramFiles%\Microsoft Office\root\Office16\POWERPNT.EXE"
if not defined PP if exist "%ProgramFiles(x86)%\Microsoft Office\root\Office16\POWERPNT.EXE" set "PP=%ProgramFiles(x86)%\Microsoft Office\root\Office16\POWERPNT.EXE"
if not defined PP ( echo error:powerpoint> "Z:\done.txt" & exit /b 1 )

del "Z:\done.txt" >nul 2>&1

set "REL="
set /p REL=<"Z:\request.txt"
if not defined REL ( echo error:request> "Z:\done.txt" & exit /b 1 )

rem Evita che l'apertura finisca su un'istanza gia' aperta (start /wait tornerebbe subito).
taskkill /im POWERPNT.EXE /f >nul 2>&1

start /wait "" "%PP%" "Z:\%REL%"
echo ok> "Z:\done.txt"
exit /b 0
