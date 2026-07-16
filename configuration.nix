# Shared system configuration — imported by all hosts.
# Machine-specific settings go in hosts/<name>/default.nix.

{ config, lib, pkgs, inputs, outputs, sharedConfig, hostConfig, ... }:

{
  # Emacs overlay for native compilation (faster startup & execution)
  nixpkgs.overlays = [
    inputs.emacs-overlay.overlay
    (final: prev: {
      passWithOtp = prev.pass.withExtensions (exts: [ exts.pass-otp ]);
      passff-host = prev.passff-host.override { pass = final.passWithOtp; };
    })
  ];

  # Unfree packages allowed on every host. A name here is only consulted when
  # that package actually enters a host's closure, so listing all of them in
  # one shared place is inert on hosts that never reference them (e.g. steam
  # on work). claude-code/claude-agent-acp are pulled in by the emacs
  # agent-shell (shared), so they must be allowed on both hosts.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "hplip"
    "steam"
    "steam-unwrapped"
    # Anthropic's CLI, pulled in by claude-agent-acp (the Claude ACP shim).
    "claude-code"
    "claude-agent-acp"
  ];

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

  # Enabling X flips on programs.ssh.enableAskPassword, which otherwise
  # defaults SSH_ASKPASS to legacy x11-ssh-askpass — an Xwayland window that
  # X-grabs the keyboard and wedges input under sway. Use wayprompt instead:
  # native wlroots, self-contained, same prompt tool as our GPG pinentry.
  programs.ssh.askPassword = "${pkgs.wayprompt}/bin/wayprompt-ssh-askpass";

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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIME8Wkm3yORpzrrWNY5UA9+gXStIlB0lawUhURHG61lO fable"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDdh1xcjq3C4TCB7F106boY5WJ8gEYsm3cj3hmRgxMYxy0N1DDTykuVW9rHguGruEOSEK7BqhU03g692KQ+r7VbzFdYFYDZpRetIH8q4dsw5XDKPYAAirJz8VW5ZuWgnhWdPxjEimopmafMbvmNNS/HTkFwFDdid9oUCdsp+aXx4NpF7GKVx7/dnN1qkYNDCpGdYrKk5YDUPIIyOK7+Q48hsFFTNkuKjBxiV8JyZN0iSXXAJs+M4cP39tSGvApFqvSu51KOjHus1yEE0XYJqcGWLDTTNwlYEbz7Z6sE08nIS+aSjieyOVI0zROTVV4496JKtXb/b3JSHe0tyJNxjMYRkSru/vE/LoQxWimKGihuZEERqjgs8hNUH7ppsFJQQpAZ/Yn+3be9h0bAhMPi2f4QEhPQV7ndqoGIiLIgPf2OHQB7uuj5jWxU3skYjYDw61Spd3VnpvHbrG06FL2Z2qOHufmsWMry7Dbj760EK86it2oDt/1Odaw8M0aB6tAgHbc= czar@bruh-moment"
    ];
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
    passWithOtp
    (writeScriptBin "tmparg" (builtins.readFile ./tmparg))
    git
    wireguard-tools
    dig
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
    # Keep builds from eating the whole machine: at most 3 derivations at
    # once, 2 build-threads each -> ~6 cores. This is the cap that actually
    # bounds `sudo nixos-rebuild` (root builds directly, bypassing the
    # daemon), so it must live here rather than only in a cgroup quota.
    cores = 2;
    max-jobs = 3;
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

  # Belt-and-suspenders hard cap for *daemon-driven* builds (non-root nix,
  # auto-gc, nix-index): everything the daemon spawns lives in this cgroup.
  # Note: `sudo nixos-rebuild` builds as root outside the daemon, so it is
  # bounded by nix.settings.cores/max-jobs above, not by this quota.
  systemd.services.nix-daemon.serviceConfig.CPUQuota = "600%";

  system.stateVersion = "25.05";
}
