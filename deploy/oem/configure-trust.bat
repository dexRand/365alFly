@echo off
rem pptx-open — rende Z:\ una trusted location di Office e disattiva il
rem Protected View per i file che arrivano dalla condivisione (vengono
rem marcati come "Internet" perche' lo share sta su una rete non intranet).
rem Gira nel contesto dell'utente: chiamato da install.bat, oppure a mano.
setlocal EnableExtensions
call :trust PowerPoint
call :trust Word
call :trust Excel
echo [pptx-open] Trusted location Z:\ configurata
exit /b 0

:trust
set "APP=%~1"
set "TL=HKCU\Software\Microsoft\Office\16.0\%APP%\Security\Trusted Locations"
set "PV=HKCU\Software\Microsoft\Office\16.0\%APP%\Security\ProtectedView"
reg add "%TL%" /v AllowNetworkLocations /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%TL%\Zdrive" /v Path /t REG_SZ /d Z:\ /f >nul 2>&1
reg add "%TL%\Zdrive" /v AllowSubfolders /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%TL%\Zdrive" /v Description /t REG_SZ /d "pptx-open shared" /f >nul 2>&1
reg add "%PV%" /v DisableInternetFilesInPV /t REG_DWORD /d 1 /f >nul 2>&1
reg add "%PV%" /v DisableUnsafeLocationsInPV /t REG_DWORD /d 1 /f >nul 2>&1
exit /b 0
