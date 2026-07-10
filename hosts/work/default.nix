# Work machine (Hyper-V VM) — machine-specific configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./hyperv.nix
    ./mounts.nix
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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
    listenAddresses = [{ addr = "192.168.100.2"; port = 22; }];
  };

  impermanence-wipe = {
    enable = true;
    device = "/dev/mapper/pool-root";
    subvolume = "@/root";
    retentionDays = null;
  };

  # Self-hosted tailnet (headscale @ vpn.hrhr.dev); `tailscale up` run once
  # imperatively with a preauth key — state persists in /var/lib/tailscale.
  services.tailscale.enable = true;

  environment.persistence."/persist".directories = [
    "/etc/ssh"
    "/var/lib/docker"
    "/var/lib/tailscale"
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  users.users.czar.extraGroups = [ "docker" ];
  environment.persistence."/persist".users.czar = {
    directories = [
      ".config/gcloud"
      ".sfdx"
      ".ansible"
      ".npm"
      ".local/share/com.vercel.cli"
      "drafts"
      "bg"
    ];
    files = [
      ".netrc"
    ];
  };
}
