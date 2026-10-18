[CmdletBinding()]
param(
    [string]$InstallDirectory = "$env:ProgramFiles\WindowsKioskLauncher",
    [string]$ConfigDirectory = "$env:ProgramData\WindowsKioskLauncher",
    [switch]$StagedCopy
)

$ErrorActionPreference = 'Stop'
$taskName = 'Windows Kiosk Baslatici'
$edgeUiPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'
$edgeSwipeValueName = 'AllowEdgeSwipe'

function Assert-SafeRemovalDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ((Split-Path -Leaf $resolvedPath) -ne 'WindowsKioskLauncher') {
        throw "Guvenlik nedeniyle yalnizca WindowsKioskLauncher klasoru silinebilir: $resolvedPath"
    }
    return $resolvedPath
}

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

$InstallDirectory = Assert-SafeRemovalDirectory -Path $InstallDirectory
$ConfigDirectory = Assert-SafeRemovalDirectory -Path $ConfigDirectory
$scriptPath = [IO.Path]::GetFullPath($PSCommandPath)

# A directory cannot be removed reliably while PowerShell is running a script
# from that same directory. Relaunch a temporary copy with a working directory
# outside Program Files, then let this original process exit immediately.
if (-not $StagedCopy -and
    ($scriptPath.Equals($InstallDirectory, [StringComparison]::OrdinalIgnoreCase) -or
     $scriptPath.StartsWith($InstallDirectory + '\', [StringComparison]::OrdinalIgnoreCase))) {
    $temporaryScript = Join-Path ([IO.Path]::GetTempPath()) `
        ("WindowsKiosk-Uninstall-{0}.ps1" -f [Guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $PSCommandPath -Destination $temporaryScript -Force
    $temporaryArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$temporaryScript`" " +
        "-InstallDirectory `"$InstallDirectory`" -ConfigDirectory `"$ConfigDirectory`" -StagedCopy"
    Start-Process -FilePath 'powershell.exe' -ArgumentList $temporaryArguments `
        -WorkingDirectory ([IO.Path]::GetTempPath()) | Out-Null
    exit 0
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argumentLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
        "-InstallDirectory `"$InstallDirectory`" -ConfigDirectory `"$ConfigDirectory`""
    if ($StagedCopy) { $argumentLine += ' -StagedCopy' }
    $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentLine -Wait -PassThru
    exit $elevated.ExitCode
}

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

Get-Process -Name 'KioskAgent', 'KioskLauncher' -ErrorAction SilentlyContinue | Stop-Process -Force
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

$edgeSwipeBackupPath = Join-Path $ConfigDirectory 'EdgeSwipePolicyBackup.json'
if (Test-Path -LiteralPath $edgeSwipeBackupPath) {
    $edgeSwipeBackup = Get-Content -Raw -LiteralPath $edgeSwipeBackupPath | ConvertFrom-Json
    New-Item -Path $edgeUiPolicyPath -Force | Out-Null
    if ([bool]$edgeSwipeBackup.HadValue) {
        Set-ItemProperty -LiteralPath $edgeUiPolicyPath -Name $edgeSwipeValueName `
            -Value ([int]$edgeSwipeBackup.Value) -Type DWord
    } else {
        $currentPolicyItem = Get-ItemProperty -LiteralPath $edgeUiPolicyPath
        if ($currentPolicyItem.PSObject.Properties.Name -contains $edgeSwipeValueName) {
            Remove-ItemProperty -LiteralPath $edgeUiPolicyPath -Name $edgeSwipeValueName
        }
    }
    Remove-Item -LiteralPath $edgeSwipeBackupPath -Force
    Write-Host 'Onceki Windows ekran kenari hareketi ilkesi geri yuklendi.'
    Write-Host 'Degisikligin uygulanmasi icin bilgisayari yeniden baslatin.' -ForegroundColor Yellow
}

$desktopShortcut = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Kiosk Baslat.lnk'
$menuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Kiosk Baslat.lnk'
foreach ($path in @($desktopShortcut, $menuShortcut)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

if (Test-Path -LiteralPath $InstallDirectory) {
    Remove-Item -LiteralPath $InstallDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $ConfigDirectory) {
    Remove-Item -LiteralPath $ConfigDirectory -Recurse -Force
}

if ((Test-Path -LiteralPath $InstallDirectory) -or (Test-Path -LiteralPath $ConfigDirectory)) {
    throw 'Kiosk klasorlerinden en az biri tamamen silinemedi.'
}

Write-Host "Silindi: $InstallDirectory"
Write-Host "Silindi: $ConfigDirectory"
Write-Host 'Kiosk uygulamasi, yapilandirmasi ve gunlukleri tamamen kaldirildi.' -ForegroundColor Green

if ($StagedCopy) {
    try { Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue } catch { }
}

Write-Host ''
Write-Host 'Cikmak icin bir tusa basin...'
try {
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
} catch {
    $null = Read-Host
}
