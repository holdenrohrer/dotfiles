<#
  uninstall.ps1 - remove the InputSyncHost presence keeper.
  Run as a local admin. Idempotent.
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$TaskName    = 'InputSyncHost'
$TaskPath    = '\'
$InstallDir  = 'C:\Users\HoldenRohrer\AppData\Local\Microsoft\InputSyncHost'

try {
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction Stop
    Write-Output "unregistered task '$TaskName'"
} catch { Write-Output "task '$TaskName' not present" }

if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force
    Write-Output "removed $InstallDir"
} else { Write-Output "install dir already gone" }
