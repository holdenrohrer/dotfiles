# WebView2Feedback / Edge issue draft — Programmer Dvorak (kbddvp.dll) crashes Chromium 151.x
# Post at: https://github.com/MicrosoftEdge/WebView2Feedback/issues/new/choose  (Report a problem/bug)
# Also worth filing via edge://feedback (Edge browser itself crashes).

Title: [Problem/Bug]: msedge.exe / WebView2 151.0.4129.x crash (0xc0000005 access violation in kbddvp.dll, "Programmer Dvorak" keyboard layout) on startup when that layout is active — regression from 151.0.4129.78

## What happened?
As of the Edge/WebView2 update to 151.0.4129.78 (installed 2026-08-12), both the
Edge browser (msedge.exe) and every WebView2 host (new Microsoft Teams, new
Outlook) CRASH ON STARTUP when the ACTIVE Windows keyboard layout is the
third-party "Programmer Dvorak" layout (kbddvp.dll, v1.2.8.0, KLID 19360409).

Windows Error Reporting (Application log, Event ID 1000):
  Faulting application name: msedge.exe, version: 151.0.4129.86
  Faulting module name:      kbddvp.dll, version: 1.2.8.0
  Exception code:            0xc0000005   (ACCESS_VIOLATION)
  Fault offset:              0x00000000000026d8

WebView2 hosts show the generic "error curtain" instead of crashing visibly; the
underlying WebView2 controller creation fails:
  webview_environment_win.cpp(703): EndCreateController got error HRESULT: 0x8000ffff
  WebViewEnvironmentWin: Failure during WebView2 environment creation: 0x8000ffff

Rigorously isolated:
- Active layout = Programmer Dvorak (kbddvp.dll)  -> Edge & WebView2 CRASH every time.
- Active layout = US QWERTY (00000409)            -> Edge & WebView2 work perfectly,
  even with Windows display language AND regional format both set to fr-CA.
- The keyboard *language* and regional format are irrelevant; only the active
  keyboard LAYOUT matters. (fr-CA appeared correlated only because it was bound
  to the Dvorak layout on this machine.)
- Programmer Dvorak merely INSTALLED (but not active) does not crash — it must be
  the active layout when the Chromium process starts.

A browser/WebView2 should not access-violate based on the active keyboard layout.
The fault is inside kbddvp.dll, so Chromium 151.x appears to call the layout DLL
(ToUnicodeEx / layout tables?) in a way the previous version did not, triggering a
latent fault in this layout binary.

## Importance
Blocking. Edge and all WebView2 apps (Teams, Outlook) fail to start.

## Runtime Channel
Stable release (WebView2 Runtime)

## Runtime Version
151.0.4129.86  (regressed at 151.0.4129.78, 2026-08-12; .86 also affected)

## SDK Version
(blank — reproduced with Edge browser and shipping WebView2 hosts)

## Framework
Other (Edge browser itself; also WebView2 hosts: new Teams / new Outlook)

## Operating System
Windows 11

## OS Version
10.0.26100 (24H2)

## Repro steps
1. Install the third-party "Programmer Dvorak" keyboard layout (kbddvp.dll,
   from kaufmann.no/roland/dvorak, KLID 19360409).
2. Make Programmer Dvorak the ACTIVE keyboard layout.
3. Launch msedge.exe (or any WebView2 host such as new Teams).

Expected: Edge / WebView2 starts normally.
Actual:   process crashes on startup with 0xc0000005 in kbddvp.dll; Edge shows no
          window, WebView2 hosts show their error page and never write
          "Local State"/"Default" in the user-data folder.

Workaround: use a different active keyboard layout (e.g. QWERTY or built-in
Dvorak KBDDV.DLL) when launching Chromium-based apps.

## Repros in Edge Browser
Yes, issue can be reproduced in the corresponding Edge version (msedge.exe crashes).

## Regression
Regression in newer Runtime.

## Last working version (if regression)
Last working: the Edge/WebView2 build immediately prior to 151.0.4129.78
(worked through ~2026-08-11; 151.0.4129.78 shipped 2026-08-12).
