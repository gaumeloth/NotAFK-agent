@echo off
setlocal enabledelayedexpansion

set "REMOTE_SCRIPT_URL=https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.ps1"
set "SCRIPT_NAME=install-windows.ps1"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%%SCRIPT_NAME%"
set "TEMP_SCRIPT="
set "RUNNER="

if exist "%SCRIPT_PATH%" (
    set "RUNNER=%SCRIPT_PATH%"
) else (
    for /f %%G in ('powershell -NoProfile -Command "[System.Guid]::NewGuid().ToString()"') do set "GUID=%%G"
    set "TEMP_SCRIPT=%TEMP%\notafk-agent-!GUID!.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%REMOTE_SCRIPT_URL%' -OutFile '%TEMP_SCRIPT%' ^| Out-Null" || (
        echo Errore durante il download dello script PowerShell da %REMOTE_SCRIPT_URL%.
        exit /b 1
    )
    set "RUNNER=%TEMP_SCRIPT%"
)

if not defined RUNNER (
    echo Errore: impossibile determinare il percorso dello script PowerShell.
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "!RUNNER!" %*
set "EXITCODE=%ERRORLEVEL%"

if defined TEMP_SCRIPT if exist "!TEMP_SCRIPT!" del /q "!TEMP_SCRIPT!"
exit /b %EXITCODE%
