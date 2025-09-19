# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  low-bat = pkgs.writeScriptBin "low-bat" ''
      #!${pkgs.bash}/bin/bash
      set_led() {
          echo $1 > /sys/class/leds/input0::capslock/brightness
      }

      composite_bat() {
          CAPACITY="$(cat /sys/class/power_supply/BAT*/energy_full_design | awk '{s+=$1} END {print s}')"
          ENERGY="$(cat /sys/class/power_supply/BAT*/energy_now | awk '{s+=$1} END {print s}')"
          echo "1000*$${ENERGY}/$${CAPACITY}" | bc
      }

      bat_below() { # takes input as per mille
          test $(cat /sys/class/power_supply/AC/online) = 0 && test $(composite_bat) -le $1
      }

      set_led 0;
      bat_below 50 && set_led 1;
      bat_below 10 && systemctl hybrid-sleep;
    '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./wireless.nix
    ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/wireguard"
      "/var/lib/nixos"
    ];
    files = [
      "/etc/wpa_supplicant.conf"
      "/etc/machine-id"
    ];
    users.czar = {
      directories = [
        ".mozilla"
        ".vim"
        "bg"
        ".gnupg"
        ".ssh"
        ".password-store"
        "projects"
        "drafts"
        ".mutt"
        ".local/share/Anki2"
        ".local/share/PrismLauncher"
      ];
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-1]", RUN+="${low-bat}/bin/low-bat off"

    SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="${low-bat}/bin/low-bat low"
    SUBSYSTEM=="power_supply", ATTR{status}=="Charging", RUN+="${low-bat}/bin/low-bat chr"
  '';

  services.logind = {
    powerKey = "hibernate";
    lidSwitch = "hybrid-sleep";
    lidSwitchExternalPower = "hybrid-sleep";
  };

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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  networking.domain = "localhost";

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.defaultSession = "sway";
  services.displayManager.autoLogin = {
    enable = true;
    user = "czar";
  };


  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "dvp";
  services.xserver.xkb.options = "caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # services.pipewire.enable = false;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.czar = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$wj9.X4U8QhhiWWDAb0TJ30$ikq5fEV1mIkY3yqyqeU7dHmcH3akxufVu/Dv7gixbF/";
    extraGroups = [ "wheel" "video" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
    ];
    shell = pkgs.zsh;
  };

  # Ensure system zsh program is enabled when zsh is the login shell
  programs.zsh.enable = true;

  # zsh config is managed via Home Manager; login shell is set system-wide above
  programs.light.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  xdg.portal.wlr.enable = true;

  # Back up files that conflict with Home Manager-managed files during activation
  home-manager.backupFileExtension = "backup";

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    sl
    low-bat
    vim
    bc
    (pass.withExtensions (exts: [ exts.pass-otp ]))
    git
    wireguard-tools
    killall
    python3
    unzip
    mutt
  ];

  services.fwupd.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1234 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?


}
