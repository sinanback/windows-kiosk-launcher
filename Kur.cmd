@echo off
set "SCRIPT_DIR=%~dp0"
set "BOOT_LOG=%SCRIPT_DIR%Kurulum-Baslatici.log"
echo ==================================================>>"%BOOT_LOG%"
echo Kurulum baslangici: %DATE% %TIME%>>"%BOOT_LOG%"
echo Paket konumu: %SCRIPT_DIR%>>"%BOOT_LOG%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%installer\Install-Kiosk.ps1" >>"%BOOT_LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"
echo Cikis kodu: %EXIT_CODE%>>"%BOOT_LOG%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo KURULUM BASARISIZ OLDU. Cikis kodu: %EXIT_CODE%
    echo Baslatici gunlugu: %BOOT_LOG%
    echo Yonetici kurulum gunlugu: %ProgramData%\WindowsKioskLauncher\Kurulum.log
    echo.
    echo Son hata ayrintilari:
    powershell.exe -NoProfile -Command "if (Test-Path -LiteralPath '%ProgramData%\WindowsKioskLauncher\Kurulum.log') { Get-Content -LiteralPath '%ProgramData%\WindowsKioskLauncher\Kurulum.log' -Tail 30 } else { Get-Content -LiteralPath '%BOOT_LOG%' -Tail 30 }"
    echo.
    pause
    exit /b %EXIT_CODE%
)

echo Kurulum tamamlandi.
echo Gunluk: %ProgramData%\WindowsKioskLauncher\Kurulum.log
pause
