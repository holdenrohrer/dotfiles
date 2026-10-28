<#
  install.ps1 - deploy the "InputSyncHost" presence keeper.

  Compiles a tiny windowless exe that injects a net-zero (+1/-1 px) mouse move
  via SendInput. The move cancels to nothing visible, but the injected input
  resets the OS idle timer (GetLastInputInfo) so the interactive session stays
  "active" and Microsoft Teams presence stays Available instead of Away.

  It nudges only while the console display is on: injected input on a closed
  lid would pull the laptop out of Modern Standby and keep it awake in a bag.

  A hidden Scheduled Task runs it as the interactive desktop user every 3 min,
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
$IntervalMin = 3                                                 # nudge cadence; keep < Teams'
                                                                 #   ~5-min Away threshold, with margin
$Days        = 'Monday','Tuesday','Wednesday','Thursday','Friday'
# ----------------------------------------------------------------------------

$InstallDir = Join-Path $UserProfile 'AppData\Local\Microsoft\InputSyncHost'
$ExePath    = Join-Path $InstallDir 'InputSyncHost.exe'

# --- 1. compile the windowless nudger --------------------------------------
$src = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

// Nudge only while the console display is lit. A closed lid (or a sleeping
// laptop briefly woken by a charger "display burst") reports the display as
// off, and injected input then would pull the machine out of Modern Standby.
class InputSyncHost {
    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx; public int dy; public uint mouseData;
                        public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public MOUSEINPUT mi; }
    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr RegisterPowerSettingNotification(IntPtr hRecipient, ref Guid PowerSettingGuid, int Flags);
    [DllImport("user32.dll")]
    static extern bool UnregisterPowerSettingNotification(IntPtr handle);

    const uint MOUSEEVENTF_MOVE = 0x0001;
    const int  WM_POWERBROADCAST = 0x0218, PBT_POWERSETTINGCHANGE = 0x8013;
    static Guid GUID_CONSOLE_DISPLAY_STATE = new Guid("6fe69556-704a-47a0-8f24-c28d936fda47");

    // Exit codes double as telemetry in the task's LastTaskResult.
    enum Display { Off = 0, On = 1, Dimmed = 2, Unknown = 255 }

    // Windows answers a fresh registration with the current value, so a
    // message-only window that listens for a moment learns the display state.
    sealed class Listener : NativeWindow {
        public Display State = Display.Unknown;
        public Listener() { CreateHandle(new CreateParams { Parent = (IntPtr)(-3) }); } // HWND_MESSAGE
        protected override void WndProc(ref Message m) {
            if (m.Msg == WM_POWERBROADCAST && (int)m.WParam == PBT_POWERSETTINGCHANGE)
                State = (Display)Marshal.ReadInt32(m.LParam, 20); // POWERBROADCAST_SETTING.Data
            base.WndProc(ref m);
        }
    }

    static Display ConsoleDisplay() {
        var l = new Listener();
        IntPtr reg = RegisterPowerSettingNotification(l.Handle, ref GUID_CONSOLE_DISPLAY_STATE, 0);
        for (var deadline = DateTime.UtcNow.AddSeconds(2);
             l.State == Display.Unknown && DateTime.UtcNow < deadline; Thread.Sleep(20))
            Application.DoEvents();
        UnregisterPowerSettingNotification(reg);
        l.DestroyHandle();
        return l.State;
    }

    static void Nudge() {
        INPUT[] a = new INPUT[2];
        a[0].mi.dx = 1;  a[0].mi.dwFlags = MOUSEEVENTF_MOVE;
        a[1].mi.dx = -1; a[1].mi.dwFlags = MOUSEEVENTF_MOVE;
        SendInput(2, a, Marshal.SizeOf(typeof(INPUT)));
    }

    static int Main(string[] args) {
        Display d = ConsoleDisplay();
        bool dry = args.Length > 0 && args[0] == "--dry";
        if (!dry && (d == Display.On || d == Display.Dimmed)) Nudge(); // unknown => stay quiet
        return (int)d;
    }
}
'@

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$srcFile = Join-Path $env:TEMP 'InputSyncHost.cs'
Set-Content -Path $srcFile -Value $src -Encoding ASCII
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /r:System.Windows.Forms.dll /optimize+ /out:"$ExePath" "$srcFile" | Out-Null
Remove-Item $srcFile -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $ExePath)) { throw "compile failed: $ExePath not produced" }
Write-Output "compiled $ExePath ($((Get-Item $ExePath).Length) bytes)"

# --- 2. (re)register the scheduled task ------------------------------------
try { Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false -ErrorAction Stop } catch {}

$at = Get-Date -Hour $StartHour -Minute 0 -Second 0
$action  = New-ScheduledTaskAction -Execute $ExePath
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Days -At $at
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At $at `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMin) `
    -RepetitionDuration (New-TimeSpan -Hours $WindowHours)).Repetition

$principal = New-ScheduledTaskPrincipal -UserId $InteractiveUser -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet `
    -RunOnlyIfNetworkAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
$settings.StartWhenAvailable = $true    # boot/wake after 08:00 -> start as soon as available
                                        #   (the repetition window still caps activity at 17:00)

Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
    -Description 'Synchronizes user input device state.' -Force | Out-Null

$ni = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $TaskPath
Write-Output "registered '$TaskName' as $InteractiveUser; next run $($ni.NextRunTime)"
