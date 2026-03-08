# Work machine (Hyper-V VM) — machine-specific configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Work-specific persistence (extend as needed)
  # environment.persistence."/persist".directories = [ ];
}
