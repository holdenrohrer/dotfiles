# install-fixed-dvorak.ps1 — install ASLR-patched Programmer Dvorak (works with Chromium/Edge 151.x)
# Root cause: stock kbddvp.dll 1.2.8 ships with DllCharacteristics=0x0000 (no DYNAMIC_BASE/ASLR).
# Edge 151.0.4129.78+ force-relocates modules; the non-ASLR-flagged DLL's pointer tables break -> 0xc0000005.
# Fix: same DLL with DllCharacteristics ASLR/DEP bits set (0x0160). Run as admin.
param([string]$x64 = "$PSScriptRoot\kbddvp2-x64.dll", [string]$x86 = "$PSScriptRoot\kbddvp2-x86.dll")
Copy-Item $x64 "C:\Windows\System32\kbddvp2.dll" -Force
Copy-Item $x86 "C:\Windows\SysWOW64\kbddvp2.dll" -Force
$k = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\a0000409"
New-Item -Path $k -Force | Out-Null
Set-ItemProperty $k -Name "Layout File" -Value "kbddvp2.dll"
Set-ItemProperty $k -Name "Layout Text" -Value "Programmer Dvorak (ASLR fix)"
Set-ItemProperty $k -Name "Layout Id"   -Value "00fe"
Write-Host "Installed KLID a0000409 (Programmer Dvorak, ASLR-fixed). Set it as your keyboard, then log out/in."
