# Work machine (Hyper-V VM) — machine-specific configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./hyperv.nix
  ];

  # Subvolumes needed early in boot (impermanence, logging)
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/lib".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
  fileSystems."/var/tmp".neededForBoot = true;

  # Work-specific persistence (extend as needed)
  # environment.persistence."/persist".directories = [ ];
}
