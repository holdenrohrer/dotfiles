# Personal laptop (ThinkPad) — machine-specific configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../wireless.nix
    ../../low-bat.nix
    ../../backup.nix
  ];

  # Personal-only persistence
  environment.persistence."/persist".directories = [
    "/etc/wireguard"
    "/var/lib/iwd"          # iwd state (known networks added imperatively)
    "/var/lib/docker"
    "/var/lib/tailscale"
    "/etc/borg"             # SSH key + passphrase for borgbackup
  ];
  environment.persistence."/persist".users.czar.directories = [
    "bg"
    "drafts"
    "games"
    ".mutt"
    ".local/share/Anki2"
    ".local/share/PrismLauncher"
    ".local/share/lutris"
  ];

  # Laptop power management
  services.logind.settings.Login = {
    powerKey = "hibernate";
    lidSwitch = "hybrid-sleep";
    lidSwitchExternalPower = "hybrid-sleep";
  };

  # Network monitoring
  services.smokeping = {
    enable = true;
    databaseConfig = ''
      step = 60
      pings = 60
      # consfn mrhb steps total
      AVERAGE  0.5   1  10080
      AVERAGE  0.5  12  43200
          MIN  0.5  12  43200
          MAX  0.5  12  43200
      AVERAGE  0.5 144   7200
          MAX  0.5 144   7200
          MIN  0.5 144   7200
    '';

    targetConfig = ''
      probe = FPing
      menu = Top
      title = Network Latency Grapher
      remark = Welcome to the SmokePing website of xxx Company. \
      Here you will learn all about the latency of our network.

      + Google
      menu = Google DNS
      title = 8.8.8.8
      host = 8.8.8.8
     '';
  };

  virtualisation.docker.enable = true;

  # mDNS for printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # 32-bit graphics for games (SPORE on WINE, Lutris)
  hardware.graphics.enable32Bit = true;

  # Unfree packages needed on personal machine
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "hplip"
    "steam"
    "steam-unwrapped"
  ];
  nixpkgs.config.permittedInsecurePackages = [
    "mbedtls-2.28.10"
  ];

  # Printing (HP)
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.hplipWithPlugin
  ];

  # Extra user groups for personal machine
  users.users.czar.extraGroups = [ "docker" "wireshark" ];

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  services.tailscale.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1234 53317 ];

  # Personal-only system packages
  environment.systemPackages = with pkgs; [
    sl
    localsend
  ];
}
