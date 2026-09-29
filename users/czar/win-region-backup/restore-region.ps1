# restore-region.ps1 - redeploy the KNOWN-GOOD (Teams-working) region+keyboard state
# Run as admin. Full effect (display language) needs logout/login.
$sid = "S-1-12-1-2179002826-1174083378-3658341544-2156305046"
$dir = "C:\Users\Public\region-backup"
reg import "$dir\International.reg" 2>&1 | Out-Null
reg import "$dir\KeyboardLayout.reg" 2>&1 | Out-Null
$pref = Get-Content "$dir\PreferredUILanguages.txt" | Where-Object { $_ }
$desk = [Microsoft.Win32.Registry]::Users.OpenSubKey("$sid\Control Panel\Desktop", $true)
$desk.SetValue("PreferredUILanguages", [string[]]$pref, [Microsoft.Win32.RegistryValueKind]::MultiString)
$desk.Close()
Add-Type -MemberDefinition '[DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,string l,uint f,uint t,out IntPtr r);' -Name U -Namespace W -PassThru | Out-Null
$r=[IntPtr]::Zero; [W.U]::SendMessageTimeout([IntPtr]0xffff,0x1A,[IntPtr]::Zero,"intl",2,3000,[ref]$r)|Out-Null
Write-Host "Region+keyboard restored to known-good. LOG OUT / IN for full effect (display language)."
