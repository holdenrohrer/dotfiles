{ config, pkgs, ... }:

let
  screenshot = pkgs.writeScriptBin "screenshot" ''
    #!${pkgs.bash}/bin/bash
    if pgrep slurp; then
      ${pkgs.killall}/bin/killall slurp
    else
      ${pkgs.slurp}/bin/slurp | ${pkgs.grim}/bin/grim "$@"
    fi
  '';
  lock = pkgs.writeShellScript "lock" ''
    exec ${pkgs.swaylock}/bin/swaylock -i "$HOME"/bg/sc -f --indicator-radius 100 -e --clock --text-color 9f19d7 --indicator
  '';
in
{
  imports = [
    ./dark-mode.nix
  ];

  # GUI/desktop programs managed at the user level
  programs.firefox.enable = true;

  programs.foot = {
    enable = true;
    settings = {
      colors = {
        alpha = 0.7;
      };
    };
  };

  # Prefer Home Manager modules where available
  services.mako.enable = true;
  programs.zathura.enable = true;

  programs.git = {
    enable = true;
    userName = "Holden Rohrer";
    userEmail = "hr@hrhr.dev";
    signing = {
      key = "7725287258F052EE45294FA428CBDAAB3BBD8D9D";
      signByDefault = true;
    };
    extraConfig = {
      pull.rebase = false;
      init.defaultBranch = "main";
      core.autocrlf = false;
    };
  };

  # GnuPG and gpg-agent with Wayland pinentry (wayprompt)
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    # Use wayprompt as the pinentry program
    pinentryPackage = pkgs.wayprompt;
    # Optional: tweak cache TTLs (uncomment to use)
    # defaultCacheTtl = 1800;
    # maxCacheTtl = 7200;
    # enableSshSupport = true;
  };

  # Packages useful in the graphical (Wayland/Sway) environment
  home.packages = with pkgs; [
    screenshot
    hyperrogue
    feh
    anki
    prismlauncher
  ];

  xdg.configFile."sway/config".source = pkgs.substituteAll {
    src = ./sway.config;

    grim = "${pkgs.grim}/bin/grim";
    wlcopy = "${pkgs.wl-clipboard}/bin/wl-copy";
    firefox = "${pkgs.firefox}/bin/firefox";
    i3status = "${pkgs.i3status}/bin/i3status";
    foot = "${pkgs.foot}/bin/foot";
    dmenu_run = "${pkgs.dmenu}/bin/dmenu_run";
    ydotool = "${pkgs.ydotool}/bin/ydotool";
    swayidle = "${pkgs.swayidle}/bin/swayidle";
    swaymsg = "${pkgs.sway}/bin/swaymsg";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    light = "${pkgs.light}/bin/light";
    wpctl = "${pkgs.pipewire}/bin/wpctl";
    sed = "${pkgs.gnused}/bin/sed";
    bc = "${pkgs.bc}/bin/bc";
    killall = "${pkgs.killall}/bin/killall";

    lock = lock;
  };
}
