# Work machine (Hyper-V VM) — machine-specific configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./hyperv.nix
  ];

  networking.interfaces."eth0" = {
    ipv4.addresses = [{
      address = "192.168.100.2";
      prefixLength = 24;
    }];
  };

  networking.defaultGateway = "192.168.100.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # No physical display — xrdp handles session launch, not greetd/uwsm
  services.greetd.enable = lib.mkForce false;
  systemd.services.display-manager.enable = false;

  # Start user systemd services (emacs, etc.) at boot without a login session
  users.users.czar.linger = true;

  # Subvolumes needed early in boot (impermanence, logging)
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/lib".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
  fileSystems."/var/tmp".neededForBoot = true;

  # Work-specific persistence (extend as needed)
  # environment.persistence."/persist".directories = [ ];
}
