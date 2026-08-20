# InputSyncHost — Teams presence keeper (Windows)

Keeps the work laptop's interactive session looking "active" so Microsoft Teams
presence stays **Available** instead of drifting to **Away** while idle.

## What it does

A ~5 KB windowless exe (`InputSyncHost.exe`, compiled from an embedded C# stub in
`install.ps1`) injects one **net-zero mouse move** (`+1px` then `-1px`) via
`SendInput`. The motion cancels to nothing you can see, but the injected input
resets the OS idle timer (`GetLastInputInfo`) — which is exactly the signal Teams
watches. Verified: idle time `3438 ms → 0 ms` after a single nudge.

A **hidden Scheduled Task** runs it as the interactive desktop user:

| Aspect | Value |
|---|---|
| Cadence | every **3 minutes** (must stay under Teams' ~5-min Away threshold, with margin) |
| Window | **08:00–17:00** local (9h repetition off an 08:00 weekly trigger) |
| Days | **Mon–Fri** |
| Online only | `RunOnlyIfNetworkAvailable` — silent when offline |
| Boot/wake | `StartWhenAvailable=$true` — **required**: without it every repetition is declared "missed" (event 153, result `0x800710E0`) and the exe never runs. Also catches late boots/wakes within the window. The 9h repetition window still caps activity at 17:00. |
| Runs as | `AzureAD\HoldenRohrer_il`, `LogonType Interactive` (only the interactive session can move the real cursor) |
| Visibility | task `Hidden`, name `InputSyncHost`, exe under `%LOCALAPPDATA%\Microsoft\InputSyncHost\` |

## Deploy

From the NixOS box (needs an SSH master to the Windows host — see repo notes),
ship-and-run the installer. The reusable base64 ship pattern:

```bash
enc() { printf '%s' "$1" | iconv -t UTF-16LE | base64 -w0; }
recv='$b=[Console]::In.ReadToEnd(); $p="$env:TEMP\_run.ps1";
      [IO.File]::WriteAllBytes($p,[Convert]::FromBase64String($b));
      & powershell -NoProfile -ExecutionPolicy Bypass -File $p'
base64 -w0 install.ps1 | ssh 192.168.100.1 "powershell -NoProfile -EncodedCommand $(enc "$recv")"
```

`install.ps1` is idempotent — re-run it to update the exe or task. To change the
schedule, days, or task name, edit the knobs block at the top and re-run.

## Uninstall

Ship-and-run `uninstall.ps1` the same way (unregisters the task, deletes the
install dir).

## Caveats

- **Verify against a *real* trigger fire, not `Start-ScheduledTask`.** A manual
  start always runs (it bypasses schedule/condition logic), so it's a false
  positive — the first cut of this task passed manual starts but silently failed
  every real 3-min trigger with "missed schedule" (`0x800710E0`) until
  `StartWhenAvailable=$true` was set. Confirm `LastTaskResult=0x0` on an
  unattended fire, e.g. watch `(Get-ScheduledTaskInfo InputSyncHost)` across a
  trigger boundary.
- **Locked screen still shows Away.** Teams reports Away when the workstation is
  locked, regardless of injected input. This keeps you Available while the
  session is *unlocked but idle* — it does not defeat a lock. (Because the 3-min
  nudge also resets the auto-lock timer, the screen shouldn't lock from idle in
  the first place, as long as any lock timeout is longer than 3 min.)
- Corporate **EDR/DLP may flag synthetic input injection**. This is a personal
  convenience tool on your own machine; it makes no attempt to evade security
  tooling.
- The trigger is wall-clock local, so it fires at 08:00 local across DST changes.
- If the interactive account name/SID changes (e.g. another AD migration), update
  `$InteractiveUser` / `$UserProfile` in `install.ps1` and re-run.
