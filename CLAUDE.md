Hi, this is my NixOS configuration home.
I try to declaratively configure as much as possible in NixOS so that rebuilding is easy!

When on the work computer (hostname = work),
we have access to Windows!
`ssh 192.168.100.1` (with no user, or user=czar) will get you remote access to PowerShell.

When we are testing and building here, I want you to build incrementally.
You are welcome to try building a complete solution all at once ONE TIME.
But if it fails, we need to incrementally build up and test components, since often we are dealing with underdocumented, unpopular APIs and weird kludgy corner situations.

This is certainly the case when I ask you to help me build something in emacs.
First, you can try running elisp using emacsclient -e inside my live emacs instance.
Once you feel you've got the code working satisfyingly, you can either ask me to try it out, or we can add it to the .el files stored here---freezing it into the configuration.

Once we have tested a configuration once (with a sudo nixos-rebuild), we try to commit each feature as early and granularly as possible.