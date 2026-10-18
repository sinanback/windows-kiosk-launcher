[CmdletBinding()]
param(
    [string]$InstallDirectory = "$env:ProgramFiles\WindowsKioskLauncher",
    [string]$ConfigDirectory = "$env:ProgramData\WindowsKioskLauncher",
    [string]$TargetUser,
    [switch]$NoAutoStart,
    [switch]$StartNow
)

$ErrorActionPreference = 'Stop'
if ($NoAutoStart -and $StartNow) {
    throw 'NoAutoStart ve StartNow ayni anda kullanilamaz; yukseltilmis Chrome baslatmamak icin islem durduruldu.'
}
$taskName = 'Windows Kiosk Baslatici'
$packageRoot = Split-Path -Parent $PSScriptRoot
$sourceApp = Join-Path $packageRoot 'app'
$sourceConfig = Join-Path $packageRoot 'config.json'
$edgeUiPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'
$edgeSwipeValueName = 'AllowEdgeSwipe'

function Show-ExplorerTaskbars {
    if (-not ('WindowsKioskInstaller.ShellTaskbars' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace WindowsKioskInstaller {
    public static class ShellTaskbars {
        private delegate bool EnumWindowsProc(IntPtr window, IntPtr parameter);
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int count);
        [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr window, int command);
        private static int shown;
        public static int ShowAll() { shown = 0; EnumWindows(ShowIfTaskbar, IntPtr.Zero); return shown; }
        private static bool ShowIfTaskbar(IntPtr window, IntPtr parameter) {
            var text = new StringBuilder(128);
            if (GetClassName(window, text, text.Capacity) > 0 &&
                (text.ToString() == "Shell_TrayWnd" || text.ToString() == "Shell_SecondaryTrayWnd")) {
                ShowWindow(window, 5); shown++;
            }
            return true;
        }
    }
}
'@
    }
    return [WindowsKioskInstaller.ShellTaskbars]::ShowAll()
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$requestedUser = if ($TargetUser) { $TargetUser } else { $identity.Name }
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argumentLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
        "-InstallDirectory `"$InstallDirectory`" -ConfigDirectory `"$ConfigDirectory`" " +
        "-TargetUser `"$requestedUser`""
    if ($NoAutoStart) { $argumentLine += ' -NoAutoStart' }
    if ($StartNow) { $argumentLine += ' -StartNow' }
    $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentLine -Wait -PassThru
    exit $elevated.ExitCode
}

# From this point on the process is elevated. Keep a durable transcript so
# installation failures can be diagnosed even if the console is closed.
New-Item -ItemType Directory -Path $ConfigDirectory -Force | Out-Null
$installLogPath = Join-Path $ConfigDirectory 'Kurulum.log'
Start-Transcript -LiteralPath $installLogPath -Append -Force | Out-Null
trap {
    Write-Host ''
    Write-Host 'KURULUM HATASI' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host 'Ayrıntılı hata:'
    $_ | Format-List * -Force | Out-Host
    Write-Host "Kurulum günlüğü: $installLogPath" -ForegroundColor Yellow
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $sourceApp 'KioskAgent.exe'))) {
    throw 'Paket içindeki app\KioskAgent.exe bulunamadı.'
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceApp 'KioskLauncher.exe'))) {
    throw 'Paket içindeki app\KioskLauncher.exe bulunamadı.'
}

# Stop an older installed instance before replacing its executable. Restore the
# shell if that older instance had it closed.
$installedAgentPath = Join-Path $InstallDirectory 'KioskAgent.exe'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}
$oldAgents = @(Get-Process -Name 'KioskAgent' -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -eq $installedAgentPath } catch { $false }
})
if ($oldAgents.Count -gt 0) {
    $oldAgents | Stop-Process -Force
    Start-Sleep -Milliseconds 750
    $currentSession = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $sessionExplorer = @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Where-Object {
        try { $_.SessionId -eq $currentSession } catch { $false }
    })
    if ($sessionExplorer.Count -eq 0) {
        Start-Process 'explorer.exe'
        Start-Sleep -Milliseconds 750
    }
    $restoredTaskbars = Show-ExplorerTaskbars
    Write-Host "Gorev cubugu pencereleri geri gosterildi: $restoredTaskbars"
    Write-Host 'Önceki kiosk ajanı güncelleme için durduruldu.'
}
if ($oldAgents.Count -eq 0) {
    $restoredTaskbars = Show-ExplorerTaskbars
    Write-Host "Gorev cubugu pencereleri geri gosterildi: $restoredTaskbars"
}

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
$logsDirectory = Join-Path $ConfigDirectory 'logs'
New-Item -ItemType Directory -Path $logsDirectory -Force | Out-Null
& "$env:SystemRoot\System32\icacls.exe" $logsDirectory /grant "${requestedUser}:(OI)(CI)M" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Kiosk kullanicisi icin gunluk klasoru izni verilemedi: $requestedUser"
}

Copy-Item -LiteralPath (Join-Path $sourceApp 'KioskAgent.exe') -Destination $InstallDirectory -Force
Copy-Item -LiteralPath (Join-Path $sourceApp 'KioskLauncher.exe') -Destination $InstallDirectory -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'installer\Uninstall-Kiosk.ps1') -Destination $InstallDirectory -Force

# Disable Windows screen-edge system gestures. This machine policy takes
# effect after Explorer or Windows is restarted. Preserve the original value
# from the first install so uninstall can restore it safely.
$edgeSwipeBackupPath = Join-Path $ConfigDirectory 'EdgeSwipePolicyBackup.json'
$edgeSwipeRestartRequired = $false
if (-not (Test-Path -LiteralPath $edgeSwipeBackupPath)) {
    $policyItem = Get-ItemProperty -LiteralPath $edgeUiPolicyPath -ErrorAction SilentlyContinue
    $hadEdgeSwipeValue = $null -ne $policyItem -and
        $policyItem.PSObject.Properties.Name -contains $edgeSwipeValueName
    $previousEdgeSwipeValue = if ($hadEdgeSwipeValue) {
        [int]$policyItem.$edgeSwipeValueName
    } else {
        $null
    }
    [ordered]@{
        HadValue = $hadEdgeSwipeValue
        Value = $previousEdgeSwipeValue
    } | ConvertTo-Json | Set-Content -LiteralPath $edgeSwipeBackupPath -Encoding UTF8
}

New-Item -Path $edgeUiPolicyPath -Force | Out-Null
$currentPolicyItem = Get-ItemProperty -LiteralPath $edgeUiPolicyPath
$hasCurrentEdgeSwipeValue = $currentPolicyItem.PSObject.Properties.Name -contains $edgeSwipeValueName
$currentEdgeSwipeValue = if ($hasCurrentEdgeSwipeValue) {
    [int]$currentPolicyItem.$edgeSwipeValueName
} else {
    $null
}
if ($currentEdgeSwipeValue -ne 0) {
    Set-ItemProperty -LiteralPath $edgeUiPolicyPath -Name $edgeSwipeValueName -Value 0 -Type DWord
    $edgeSwipeRestartRequired = $true
}
Write-Host 'Windows ekran kenari sistem hareketleri devre disi birakildi.'

$installedConfig = Join-Path $ConfigDirectory 'config.json'
if (-not (Test-Path -LiteralPath $installedConfig)) {
    Copy-Item -LiteralPath $sourceConfig -Destination $installedConfig
    Write-Host "Yeni yapılandırma oluşturuldu: $installedConfig"
} else {
    Write-Host "Mevcut yapılandırma korundu: $installedConfig"
}

$agentPath = Join-Path $InstallDirectory 'KioskAgent.exe'
$action = New-ScheduledTaskAction -Execute $agentPath -Argument "--config `"$installedConfig`" --silent"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $requestedUser
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $requestedUser -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)

if (-not $NoAutoStart) {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $taskPrincipal -Settings $settings -Description 'Chrome kiosk oturum ajanı' -Force | Out-Null
    Write-Host "Oturum açılış görevi kaydedildi: $requestedUser"
}

$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
foreach ($shortcutPath in @(
    (Join-Path $desktop 'Kiosk Baslat.lnk'),
    (Join-Path $startMenu 'Kiosk Baslat.lnk')
)) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $InstallDirectory 'KioskLauncher.exe'
    $shortcut.WorkingDirectory = $InstallDirectory
    $shortcut.Description = 'Windows kiosk modunu manuel başlatır'
    $shortcut.Save()
}

if ($StartNow) {
    if ($NoAutoStart) {
        Start-Process -FilePath $agentPath -ArgumentList @('--config', $installedConfig)
    } else {
        Start-ScheduledTask -TaskName $taskName
    }
}

Write-Host ''
Write-Host 'Kurulum tamamlandı.' -ForegroundColor Green
Write-Host "Yapılandırma: $installedConfig"
Write-Host 'Manuel başlatma: Masaüstündeki Kiosk Baslat kısayolu'
Write-Host 'Kiosk modundan çıkış: Ctrl+5'
Write-Host "Kurulum günlüğü: $installLogPath"
if ($edgeSwipeRestartRequired) {
    Write-Host 'ONEMLI: Dokunmatik kenar hareketi ayarinin uygulanmasi icin bilgisayari yeniden baslatin.' -ForegroundColor Yellow
}
Stop-Transcript | Out-Null
