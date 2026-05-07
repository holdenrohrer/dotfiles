# Shared system configuration — imported by all hosts.
# Machine-specific settings go in hosts/<name>/default.nix.

{ config, lib, pkgs, inputs, outputs, sharedConfig, hostConfig, ... }:

{
  # Emacs overlay for native compilation (faster startup & execution)
  nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostConfig.hostname;
  networking.domain = "localhost";

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Xwayland support
  services.xserver.enable = true;

  # Use uwsm to properly manage Wayland session lifecycle
  # (environment import to systemd, graphical-session.target, clean shutdown)
  programs.uwsm = {
    enable = true;
    waylandCompositors.sway = {
      binPath = "${pkgs.sway}/bin/sway";
      prettyName = "Sway";
    };
  };

  # Use greetd - LightDM creates a fake graphical-session.target that
  # prevents uwsm from managing the session properly
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.uwsm}/bin/uwsm start -- ${pkgs.sway}/bin/sway";
      user = "czar";
    };
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = sharedConfig.keyboard.layout;
  services.xserver.xkb.variant = sharedConfig.keyboard.variant;
  services.xserver.xkb.options = sharedConfig.keyboard.options;

  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  security.sudo.wheelNeedsPassword = false;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.czar = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$wj9.X4U8QhhiWWDAb0TJ30$ikq5fEV1mIkY3yqyqeU7dHmcH3akxufVu/Dv7gixbF/";
    extraGroups = [ "wheel" "video" "networkmanager" ];
    packages = with pkgs; [
      tree
    ];
    shell = pkgs.zsh;
  };

  # Ensure system zsh program is enabled when zsh is the login shell
  programs.zsh.enable = true;

  programs.light.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  hardware.graphics.enable = true;

  xdg.portal.wlr.enable = true;

  # Back up files that conflict with Home Manager-managed files during activation
  home-manager.backupFileExtension = "backup";

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    (pass.withExtensions (exts: [ exts.pass-otp ]))
    (writeScriptBin "tmparg" (builtins.readFile ./tmparg))
    git
    wireguard-tools
    killall
    python3
    unzip
    nix-index
  ];

  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
  };

  services.fwupd.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "czar" ];
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
    persistent = true;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "daily" ];
    persistent = true;
  };

  system.stateVersion = "25.05";
}
