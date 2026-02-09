{ config, pkgs, inputs, outputs, sharedConfig, ... }:

let
  screenshot = pkgs.writeScriptBin "screenshot" ''
    #!${pkgs.bash}/bin/bash
    if ${pkgs.procps}/bin/pgrep slurp; then
      ${pkgs.killall}/bin/killall slurp
    else
      ${pkgs.slurp}/bin/slurp | ${pkgs.grim}/bin/grim "$@"
    fi
  '';
  lock = pkgs.writeShellScript "lock" ''
    exec ${pkgs.swaylock-effects}/bin/swaylock -i "$HOME"/bg/sc -f --indicator-radius 100 -e --clock --text-color 9f19d7 --indicator
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
    settings = {
      user = {
        name = "Holden Rohrer";
        email = "hr@hrhr.dev";
      };
      pull.rebase = false;
      init.defaultBranch = "main";
      core = {
        autocrlf = false;
        editor = "emacsclient -t -a emacs";
      };
    };
    signing = {
      key = "7725287258F052EE45294FA428CBDAAB3BBD8D9D";
      signByDefault = true;
    };
  };

  # GnuPG and gpg-agent with Wayland pinentry (wayprompt)
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    # Use wayprompt as the pinentry program
    pinentry.package = pkgs.wayprompt;
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
    lutris
    signal-desktop
    wl-clipboard
    adwaita-icon-theme
  ];

  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = [
          "wlr"
        ];
      };
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
    ];
  };

  xdg.configFile."sway/config".source = pkgs.substitute {
    name = "sway.config";
    src = ./sway.config;
    substitutions = [
      "--replace" "@grim@" "${pkgs.lib.getExe pkgs.grim}"
      "--replace" "@wlcopy@" "${pkgs.lib.getExe' pkgs.wl-clipboard "wl-copy"}"
      "--replace" "@firefox@" "${pkgs.lib.getExe pkgs.firefox}"
      "--replace" "@i3status@" "${pkgs.lib.getExe' pkgs.i3status "i3status"}"
      "--replace" "@foot@" "${pkgs.lib.getExe pkgs.foot}"
      "--replace" "@dmenu_run@" "${pkgs.lib.getExe' pkgs.dmenu "dmenu_run"}"
      "--replace" "@ydotool@" "${pkgs.lib.getExe' pkgs.ydotool "ydotool"}"
      "--replace" "@swayidle@" "${pkgs.lib.getExe' pkgs.swayidle "swayidle"}"
      "--replace" "@swaymsg@" "${pkgs.lib.getExe' pkgs.sway "swaymsg"}"
      "--replace" "@systemctl@" "${pkgs.lib.getExe' pkgs.systemd "systemctl"}"
      "--replace" "@light@" "${pkgs.lib.getExe' pkgs.light "light"}"
      "--replace" "@wpctl@" "${pkgs.lib.getExe' pkgs.wireplumber "wpctl"}"
      "--replace" "@sed@" "${pkgs.lib.getExe' pkgs.gnused "sed"}"
      "--replace" "@bc@" "${pkgs.lib.getExe' pkgs.bc "bc"}"
      "--replace" "@killall@" "${pkgs.lib.getExe' pkgs.killall "killall"}"
      "--replace" "@lock@" "${lock}"
      "--replace" "@XKB_LAYOUT@" "${sharedConfig.keyboard.layout}"
      "--replace" "@XKB_VARIANT@" "${sharedConfig.keyboard.variant}"
      "--replace" "@XKB_OPTIONS@" "${sharedConfig.keyboard.options}"
      "--replace" "@uwsm@" "${pkgs.lib.getExe pkgs.uwsm}"
    ];
  };
}
