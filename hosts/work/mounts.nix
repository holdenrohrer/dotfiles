# Network mounts — Windows filesystem (SMB) and OneDrive via SMB symlinks

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cifs-utils ];

  # SMB automount for Windows C: drive
  fileSystems."/mnt/win" = {
    device = "//192.168.100.1/C$";
    fsType = "cifs";
    options = [
      "credentials=/persist/etc/samba/credentials"
      "uid=czar"
      "gid=users"
      "file_mode=0644"
      "dir_mode=0755"
      "vers=3.1.1"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
      "_netdev"
    ];
  };

  # Symlinks for convenient OneDrive access through the SMB mount
  systemd.tmpfiles.rules = [
    "d /mnt/onedrive 0755 czar users -"
    "L+ /mnt/onedrive/personal - - - - /mnt/win/Users/HoldenRohrer/OneDrive"
    "L+ /mnt/onedrive/business - - - - /mnt/win/Users/HoldenRohrer/OneDrive - hellosyncx.com"
  ];
}
