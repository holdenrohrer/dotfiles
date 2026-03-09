{ config, pkgs, inputs, outputs, sharedConfig, hostConfig, ... }:

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
  programs.firefox = {
    enable = true;
    profiles.default = {
      id = 0;
      isDefault = true;

      search = {
        default = "Kagi";
        force = true;
        engines = {
          "Kagi" = {
            urls = [{ template = "https://kagi.com/search?q={searchTerms}"; }];
            definedAliases = [ "@k" "@kagi" ];
          };
          "google".metaData.hidden = true;
          "bing".metaData.hidden = true;
          "amazondotcom".metaData.hidden = true;
          "ddg".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "wikipedia".metaData.hidden = true;
        };
      };

      settings = {
        # Startup: restore previous session
        "browser.startup.page" = 3;

        # Privacy
        "privacy.donottrackheader.enabled" = true;
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;
        "signon.rememberSignons" = false;
        "privacy.clearOnShutdown_v2.formdata" = true;

        # UI
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        "browser.fullscreen.autohide" = false;
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # Misc
        "layout.spellcheckDefault" = 0;
        "intl.regional_prefs.use_os_locales" = true;
        "browser.translations.neverTranslateLanguages" = "fr";
        "browser.ml.chat.provider" = "https://claude.ai/new";

        # Downloads: auto-delete from private browsing
        "browser.download.deletePrivate" = true;
        "browser.download.deletePrivate.chosen" = true;
      };
    };
  };

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
        email = hostConfig.git.email;
      };
      pull.rebase = false;
      init.defaultBranch = "main";
      core.autocrlf = false;
    };
    signing = {
      key = hostConfig.git.signingKey;
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
    feh
    anki
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
