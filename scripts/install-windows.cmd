@echo off
setlocal

set "REMOTE_SCRIPT_URL=https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.ps1"
set "SCRIPT_NAME=install-windows.ps1"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%%SCRIPT_NAME%"
set "DOWNLOADED_SCRIPT="
set "RUNNER="

if exist "%SCRIPT_PATH%" (
    set "RUNNER=%SCRIPT_PATH%"
) else (
    call :download_script || goto :error
)

if not defined RUNNER (
    goto :error
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" %*
set "EXITCODE=%ERRORLEVEL%"

if defined DOWNLOADED_SCRIPT if exist "%RUNNER%" del /q "%RUNNER%"
exit /b %EXITCODE%

:download_script
for /f %%G in ('powershell -NoProfile -Command "[System.Guid]::NewGuid().ToString()"') do set "GUID=%%G"
if not defined GUID (
    echo Errore: impossibile generare un nome temporaneo.
    exit /b 1
)
set "RUNNER=%TEMP%\notafk-agent-%GUID%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%REMOTE_SCRIPT_URL%' -OutFile '%RUNNER%'" >nul || (
    echo Errore durante il download dello script PowerShell da %REMOTE_SCRIPT_URL%.
    set "RUNNER="
    exit /b 1
)
set "DOWNLOADED_SCRIPT=1"
exit /b 0

:error
echo Errore: impossibile determinare il percorso dello script PowerShell.
exit /b 1
