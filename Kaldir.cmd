@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "UNINSTALL_SCRIPT=%SCRIPT_DIR%installer\Uninstall-Kiosk.ps1"

if not exist "%UNINSTALL_SCRIPT%" (
    echo KALDIRMA HATASI: %UNINSTALL_SCRIPT% bulunamadi.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%UNINSTALL_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo KALDIRMA BASARISIZ OLDU. Cikis kodu: %EXIT_CODE%
    echo.
    pause
    exit /b %EXIT_CODE%
)

exit /b 0
