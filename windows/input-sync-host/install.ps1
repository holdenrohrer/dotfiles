<#
  install.ps1 - deploy the "InputSyncHost" presence keeper.

  Compiles a tiny windowless exe that injects a net-zero (+1/-1 px) mouse move
  via SendInput. The move cancels to nothing visible, but the injected input
  resets the OS idle timer (GetLastInputInfo) so the interactive session stays
  "active" and Microsoft Teams presence stays Available instead of Away.

  A hidden Scheduled Task runs it as the interactive desktop user every 5 min,
  Mon-Fri, 08:00-17:00 local, only while a network connection is available.

  Run this as a local admin (e.g. the SSH `czar` account). Idempotent.
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ---- knobs -----------------------------------------------------------------
$TaskName    = 'InputSyncHost'                                   # rename here to taste
$TaskPath    = '\'                                               # Task Scheduler folder
$InteractiveUser = 'AzureAD\HoldenRohrer_il'                     # whose desktop to nudge
$UserProfile = 'C:\Users\HoldenRohrer'                           # that user's profile root
$StartHour   = 8                                                 # 08:00 local
$WindowHours = 9                                                 # => last fire by 17:00
$Days        = 'Monday','Tuesday','Wednesday','Thursday','Friday'
# ----------------------------------------------------------------------------

$InstallDir = Join-Path $UserProfile 'AppData\Local\Microsoft\InputSyncHost'
$ExePath    = Join-Path $InstallDir 'InputSyncHost.exe'

# --- 1. compile the windowless nudger --------------------------------------
$src = @'
using System;
using System.Runtime.InteropServices;
class InputSyncHost {
    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx; public int dy; public uint mouseData;
                        public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public MOUSEINPUT mi; }
    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    const uint MOUSEEVENTF_MOVE = 0x0001;
    static void Main() {
        INPUT[] a = new INPUT[2];
        a[0].mi.dx = 1;  a[0].mi.dwFlags = MOUSEEVENTF_MOVE;
        a[1].mi.dx = -1; a[1].mi.dwFlags = MOUSEEVENTF_MOVE;
        SendInput(2, a, Marshal.SizeOf(typeof(INPUT)));
    }
}
'@

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$srcFile = Join-Path $env:TEMP 'InputSyncHost.cs'
Set-Content -Path $srcFile -Value $src -Encoding ASCII
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /optimize+ /out:"$ExePath" "$srcFile" | Out-Null
Remove-Item $srcFile -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $ExePath)) { throw "compile failed: $ExePath not produced" }
Write-Output "compiled $ExePath ($((Get-Item $ExePath).Length) bytes)"

# --- 2. (re)register the scheduled task ------------------------------------
try { Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction Stop } catch {}

$at = Get-Date -Hour $StartHour -Minute 0 -Second 0
$action  = New-ScheduledTaskAction -Execute $ExePath
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Days -At $at
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At $at `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Hours $WindowHours)).Repetition

$principal = New-ScheduledTaskPrincipal -UserId $InteractiveUser -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet `
    -RunOnlyIfNetworkAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
$settings.StartWhenAvailable = $false   # no off-hours catch-up nudges

Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
    -Description 'Synchronizes user input device state.' -Force | Out-Null

$ni = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $TaskPath
Write-Output "registered '$TaskName' as $InteractiveUser; next run $($ni.NextRunTime)"
