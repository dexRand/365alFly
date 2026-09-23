@echo off
rem pptx-open — scarica l'Office Deployment Tool e installa Office usando la
rem configuration.xml generata sull'host da scripts/pptx-deploy.sh.
setlocal EnableExtensions

set "ODT_DIR=C:\OEM\office\odt"
set "ODT_URL="
if exist "C:\OEM\office\odt-url.txt" (
  set /p ODT_URL=<"C:\OEM\office\odt-url.txt"
)
if "%ODT_URL%"=="" set "ODT_URL=https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe"

if exist "%ODT_DIR%\setup.exe" goto :configure

echo [pptx-open] Download Office Deployment Tool...
curl.exe -L --fail --retry 3 --output "C:\OEM\office\odt.exe" "%ODT_URL%"
if errorlevel 1 (
  echo [pptx-open] ERRORE: download ODT fallito da %ODT_URL%
  exit /b 1
)

mkdir "%ODT_DIR%" 2>nul
echo [pptx-open] Estrazione ODT...
"C:\OEM\office\odt.exe" /extract:"%ODT_DIR%" /quiet
if not exist "%ODT_DIR%\setup.exe" (
  echo [pptx-open] ERRORE: setup.exe non trovato dopo l'estrazione
  exit /b 1
)

:configure
echo [pptx-open] Installazione Office in corso (10-20 minuti)...
"%ODT_DIR%\setup.exe" /configure "C:\OEM\office\configuration.xml"
if errorlevel 1 (
  echo [pptx-open] ERRORE: installazione Office fallita (vedi C:\OEM\office\ODT.log)
  exit /b 1
)

echo [pptx-open] Office installato
exit /b 0
