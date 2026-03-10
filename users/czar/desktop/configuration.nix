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

  xclip = "${pkgs.xclip}/bin/xclip";
  wlCopy = "${pkgs.lib.getExe' pkgs.wl-clipboard "wl-copy"}";
  wlPaste = "${pkgs.lib.getExe' pkgs.wl-clipboard "wl-paste"}";

  clipW2X = pkgs.writeShellScript "clip-w2x" ''
    CONTENT=$(cat)
    LAST=$(cat /tmp/.clipbridge-last 2>/dev/null) || true
    if [ -n "$CONTENT" ] && [ "$CONTENT" != "$LAST" ]; then
      printf '%s' "$CONTENT" > /tmp/.clipbridge-last
      printf '%s' "$CONTENT" | ${xclip} -selection clipboard -display "$1"
    fi
  '';

  swaymsg = "${pkgs.lib.getExe' pkgs.sway "swaymsg"}";
  xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
  xdotool = "${pkgs.xdotool}/bin/xdotool";
  xev = "${pkgs.xorg.xev}/bin/xev";

  xrdpMultimon = pkgs.writeShellScript "xrdp-multimon" ''
    [ -z "$XRDP_XDISPLAY" ] && exit 0

    STATE_FILE="/tmp/.xrdp-multimon-map"

    configure() {
      # 1. Parse xrandr: map rdp output names to their geometries
      declare -A rdp_geom
      while IFS= read -r line; do
        if [[ $line =~ ^(rdp[0-9]+)\ connected\ ([0-9]+x[0-9]+\+[0-9]+\+[0-9]+) ]]; then
          rdp_geom["''${BASH_REMATCH[1]}"]="''${BASH_REMATCH[2]}"
        fi
      done < <(DISPLAY="$XRDP_XDISPLAY" ${xrandr} --current)

      [ "''${#rdp_geom[@]}" -eq 0 ] && return

      # 2. Read state file (X11-N=rdpN mappings from previous run)
      declare -A map_x2r map_r2x
      if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r x11 rdp; do
          [ -n "$x11" ] && [ -n "$rdp" ] && {
            map_x2r["$x11"]="$rdp"
            map_r2x["$rdp"]="$x11"
          }
        done < "$STATE_FILE"
      fi

      # 3. Enumerate X11 windows (sorted ascending by wid = X11-1, X11-2, ...)
      wids=()
      root_wid=$(DISPLAY="$XRDP_XDISPLAY" ${xdotool} search --maxdepth 0 --name "" 2>/dev/null | head -1)
      while IFS= read -r wid; do
        [ "$wid" = "$root_wid" ] && continue
        geom=$(DISPLAY="$XRDP_XDISPLAY" ${xdotool} getwindowgeometry --shell "$wid" 2>/dev/null)
        eval "$geom"
        [ "''${WIDTH:-0}" -gt 100 ] && wids+=("$wid")
      done < <(DISPLAY="$XRDP_XDISPLAY" ${xdotool} search --name "" 2>/dev/null | sort -n)

      # 4. Reconcile mappings with current rdp outputs
      declare -A used_x11
      to_remove=()

      # 4a. Existing mappings: keep if rdp output still exists, mark for removal otherwise
      for x11 in "''${!map_x2r[@]}"; do
        rdp="''${map_x2r[$x11]}"
        if [ -n "''${rdp_geom[$rdp]+_}" ]; then
          geom="''${rdp_geom[$rdp]}"
          w="''${geom%%x*}"; rest="''${geom#*x}"
          h="''${rest%%+*}"; rest="''${rest#*+}"
          x="''${rest%%+*}"; y="''${rest#*+}"

          ${swaymsg} output "$x11" enable mode "''${w}x''${h}"

          idx="''${x11#X11-}"
          wid_idx=$((idx - 1))
          if [ "$wid_idx" -ge 0 ] && [ "$wid_idx" -lt "''${#wids[@]}" ]; then
            DISPLAY="$XRDP_XDISPLAY" ${xdotool} windowsize "''${wids[$wid_idx]}" "$w" "$h"
            DISPLAY="$XRDP_XDISPLAY" ${xdotool} windowmove "''${wids[$wid_idx]}" "$x" "$y"
          fi

          used_x11["$x11"]=1
        else
          ${swaymsg} output "$x11" disable 2>/dev/null || true
          to_remove+=("$x11")
        fi
      done

      for x11 in "''${to_remove[@]}"; do
        rdp="''${map_x2r[$x11]}"
        unset "map_x2r[$x11]"
        unset "map_r2x[$rdp]"
      done

      # 4b. New rdp outputs: assign lowest unused X11-N
      for rdp in "''${!rdp_geom[@]}"; do
        [ -n "''${map_r2x[$rdp]+_}" ] && continue

        for i in $(seq 1 ''${WLR_X11_OUTPUTS:-6}); do
          x11="X11-$i"
          [ -n "''${used_x11[$x11]+_}" ] && continue

          geom="''${rdp_geom[$rdp]}"
          w="''${geom%%x*}"; rest="''${geom#*x}"
          h="''${rest%%+*}"; rest="''${rest#*+}"
          x="''${rest%%+*}"; y="''${rest#*+}"

          ${swaymsg} output "$x11" enable mode "''${w}x''${h}"

          wid_idx=$((i - 1))
          if [ "$wid_idx" -ge 0 ] && [ "$wid_idx" -lt "''${#wids[@]}" ]; then
            DISPLAY="$XRDP_XDISPLAY" ${xdotool} windowsize "''${wids[$wid_idx]}" "$w" "$h"
            DISPLAY="$XRDP_XDISPLAY" ${xdotool} windowmove "''${wids[$wid_idx]}" "$x" "$y"
          fi

          map_x2r["$x11"]="$rdp"
          map_r2x["$rdp"]="$x11"
          used_x11["$x11"]=1
          break
        done
      done

      # Disable remaining unused X11 outputs
      for i in $(seq 1 ''${WLR_X11_OUTPUTS:-6}); do
        x11="X11-$i"
        if [ -z "''${used_x11[$x11]+_}" ]; then
          ${swaymsg} output "$x11" disable 2>/dev/null || true
        fi
      done

      # 5. Write updated state file
      : > "$STATE_FILE"
      for x11 in "''${!map_x2r[@]}"; do
        echo "$x11=''${map_x2r[$x11]}" >> "$STATE_FILE"
      done
    }

    # Initial configuration
    configure

    # Watch for RandR changes (monitors added/removed) and reconfigure
    DISPLAY="$XRDP_XDISPLAY" ${xev} -root -event randr 2>/dev/null | while read -r line; do
      if [[ "$line" == *"RRScreenChangeNotify"* ]]; then
        configure
      fi
    done
  '';

  clipbridge = pkgs.writeShellScript "clipbridge-xrdp" ''
    [ -z "$XRDP_XDISPLAY" ] && exit 0
    rm -f /tmp/.clipbridge-last

    # Wayland → X11 (copy in Linux → paste in Windows)
    ${wlPaste} --watch ${clipW2X} "$XRDP_XDISPLAY" &

    # X11 → Wayland (copy in Windows → paste in Linux)
    while DISPLAY="$XRDP_XDISPLAY" ${pkgs.clipnotify}/bin/clipnotify; do
      CONTENT=$(${xclip} -selection clipboard -display "$XRDP_XDISPLAY" -o 2>/dev/null) || true
      LAST=$(cat /tmp/.clipbridge-last 2>/dev/null) || true
      if [ -n "$CONTENT" ] && [ "$CONTENT" != "$LAST" ]; then
        printf '%s' "$CONTENT" > /tmp/.clipbridge-last
        printf '%s' "$CONTENT" | ${wlCopy}
      fi
    done
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
      "--replace" "@swayidle@" "${if hostConfig.hostname == "work" then "true" else pkgs.lib.getExe' pkgs.swayidle "swayidle"}"
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
      "--replace" "@clipbridge@" "${clipbridge}"
      "--replace" "@xrdp-multimon@" "${xrdpMultimon}"
    ];
  };
}
