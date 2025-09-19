{ config, lib, pkgs, ... }:

{
  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.dhcpcd.enable = true;
  networking.networkmanager.enable = false;

  networking.dhcpcd.extraConfig = ''
    nolink
    persistent
  '';
}

