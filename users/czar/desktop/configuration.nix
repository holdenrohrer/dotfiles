{ config, lib, pkgs, inputs, outputs, sharedConfig, hostConfig, ... }:

let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [ pkgs.procps pkgs.killall pkgs.slurp pkgs.grim ];
    text = ''
      if pgrep slurp; then
        killall slurp
      else
        slurp | grim "$@"
      fi
    '';
  };

  lock = pkgs.writeShellScript "lock" ''
    exec ${pkgs.swaylock-effects}/bin/swaylock -i "$HOME"/bg/sc -f --indicator-radius 100 -e --clock --text-color 9f19d7 --indicator
  '';

  clipW2X = pkgs.writeShellApplication {
    name = "clip-w2x";
    runtimeInputs = [ pkgs.coreutils pkgs.xclip ];
    text = ''
      CONTENT=$(cat)
      LAST=$(cat /tmp/.clipbridge-last 2>/dev/null) || true
      if [ -n "$CONTENT" ] && [ "$CONTENT" != "$LAST" ]; then
        printf '%s' "$CONTENT" > /tmp/.clipbridge-last
        printf '%s' "$CONTENT" | xclip -selection clipboard -display "$1"
      fi
    '';
  };

  openUrl = pkgs.writeShellApplication {
    name = "open-url";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.sway ];
    text = ''
      url="$1"
      [ -z "$url" ] && exit 1
      export SWAYSOCK
      SWAYSOCK=$(find /run/user/1000 -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit 2>/dev/null) || true
      [ -z "$SWAYSOCK" ] && exit 1
      exec swaymsg exec "firefox '$url'"
    '';
  };

  urlWatcher = pkgs.writeShellApplication {
    name = "url-watcher";
    runtimeInputs = [ pkgs.coreutils openUrl ];
    text = ''
      DROPDIR=/mnt/win/Users/HoldenRohrer/.linux-urls
      mkdir -p "$DROPDIR" 2>/dev/null || true
      echo "url-watcher: polling $DROPDIR"
      while true; do
        for f in "$DROPDIR"/*.url; do
          [ -e "$f" ] || continue
          url=$(tr -d '\r"' < "$f" 2>/dev/null) || continue
          rm -f "$f"
          url="''${url%"''${url##*[![:space:]]}"}"
          [ -z "$url" ] && continue
          echo "url-watcher: opening $url"
          open-url "$url" || true
        done
        sleep 0.5
      done
    '';
  };

  xrdpMultimon = pkgs.writeShellApplication {
    name = "xrdp-multimon";
    excludeShellChecks = [ "SC2207" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sway
      pkgs.python3
      pkgs.xorg.xrandr
      pkgs.xdotool
      pkgs.xorg.xev
      pkgs.procps
    ];
    text = ''
      [ -z "''${XRDP_XDISPLAY:-}" ] && exit 0
      MAX_OUTPUTS="''${WLR_X11_OUTPUTS:-6}"
      STATE_FILE="/tmp/xrdp-multimon.state"

      log() { echo "xrdp-multimon: $*"; }

      wait_for_outputs() {
        local attempts=0
        while [ "$attempts" -lt 30 ]; do
          local count
          count=$(swaymsg -t get_outputs -r | python3 -c \
            "import json,sys; print(len(json.loads(sys.stdin.read())))" 2>/dev/null) || count=0
          if [ "$count" -ge "$MAX_OUTPUTS" ]; then
            log "all $MAX_OUTPUTS sway outputs ready"
            return 0
          fi
          log "waiting for outputs ($count/$MAX_OUTPUTS)..."
          sleep 0.5
          attempts=$((attempts + 1))
        done
        log "ERROR: timed out waiting for outputs ($count/$MAX_OUTPUTS after 15s)"
        return 1
      }

      configure() {
        # 1. Parse xrandr: collect rdp outputs with geometries
        declare -A rdp_geom
        while IFS= read -r line; do
          if [[ $line =~ ^(rdp[0-9]+)\ connected\ (primary\ )?([0-9]+x[0-9]+\+[0-9]+\+[0-9]+) ]]; then
            rdp_geom["''${BASH_REMATCH[1]}"]="''${BASH_REMATCH[3]}"
          fi
        done < <(DISPLAY="$XRDP_XDISPLAY" xrandr --current)

        if [ "''${#rdp_geom[@]}" -eq 0 ]; then
          log "WARNING: no rdp outputs found from xrandr"
          return
        fi
        log "found ''${#rdp_geom[@]} rdp output(s)"

        # 2. Load state db: rdp# -> workspace#
        declare -A db
        if [ -f "$STATE_FILE" ]; then
          while IFS='=' read -r key val; do
            [ -n "$key" ] && db["$key"]="$val"
          done < "$STATE_FILE"
          log "loaded state: $(declare -p db)"
        fi

        # 3. Build available workspace pool [1..10]
        declare -A avail
        for n in $(seq 1 10); do avail[$n]=1; done

        # 4. Apply existing mappings for active rdp outputs, remove from pool
        declare -A ws_map  # rdp# -> workspace# for this run
        for rdp in "''${!rdp_geom[@]}"; do
          if [ -n "''${db[$rdp]:-}" ]; then
            ws_map["$rdp"]="''${db[$rdp]}"
            unset "avail[''${db[$rdp]}]"
            log "sticky: $rdp -> workspace ''${db[$rdp]}"
          fi
        done

        # 5. Assign new rdp outputs: sort by (x,y) offset, pick smallest available ws#
        new_rdps=()
        for rdp in "''${!rdp_geom[@]}"; do
          [ -n "''${ws_map[$rdp]:-}" ] && continue
          geom="''${rdp_geom[$rdp]}"
          rest="''${geom#*+}"; x="''${rest%%+*}"; y="''${rest#*+}"
          new_rdps+=("$(printf '%06d %06d %s' "$x" "$y" "$rdp")")
        done
        IFS=$'\n' new_rdps=($(printf '%s\n' "''${new_rdps[@]}" | sort)); unset IFS

        for entry in "''${new_rdps[@]}"; do
          rdp="''${entry##* }"
          # find smallest available workspace
          local smallest=""
          for n in $(printf '%s\n' "''${!avail[@]}" | sort -n); do
            smallest="$n"; break
          done
          if [ -z "$smallest" ]; then
            log "ERROR: no workspace available for $rdp"
            continue
          fi
          ws_map["$rdp"]="$smallest"
          db["$rdp"]="$smallest"
          unset "avail[$smallest]"
          log "new: $rdp -> workspace $smallest"
        done

        # 6. Save state
        : > "$STATE_FILE"
        for rdp in "''${!db[@]}"; do
          echo "$rdp=''${db[$rdp]}" >> "$STATE_FILE"
        done

        # 7. Enumerate X11 windows (sorted ascending by wid = X11-1, X11-2, ...)
        # Take the first MAX_OUTPUTS non-root windows by ascending XID.
        # Sway's windows are created at session start so they always have the
        # lowest XIDs; xrdp internals (0x800001+) sort after them.
        wids=()
        root_wid=$(DISPLAY="$XRDP_XDISPLAY" xdotool search --maxdepth 0 --name "" 2>/dev/null | head -1) || true
        while IFS= read -r wid; do
          [ "$wid" = "$root_wid" ] && continue
          wids+=("$wid")
          [ "''${#wids[@]}" -ge "$MAX_OUTPUTS" ] && break
        done < <(DISPLAY="$XRDP_XDISPLAY" xdotool search --name "" 2>/dev/null | sort -n)
        log "found ''${#wids[@]} X11 window(s) (expected $MAX_OUTPUTS)"

        # 8. Disable all outputs and hide all X11 windows
        for j in $(seq 1 "$MAX_OUTPUTS"); do
          swaymsg output "X11-$j" disable || true
          wid_idx=$((j - 1))
          if [ "$wid_idx" -lt "''${#wids[@]}" ]; then
            DISPLAY="$XRDP_XDISPLAY" xdotool windowsize "''${wids[$wid_idx]}" 1 1 || true
            DISPLAY="$XRDP_XDISPLAY" xdotool windowmove "''${wids[$wid_idx]}" 0 0 || true
          fi
        done
        log "all outputs disabled"

        # 9. Enable outputs for active rdp monitors, bind workspaces
        # Sort active rdps by assigned workspace# to assign X11-1,2,3... in ws order
        sorted_active=()
        for rdp in "''${!ws_map[@]}"; do
          sorted_active+=("''${ws_map[$rdp]} $rdp")
        done
        IFS=$'\n' sorted_active=($(printf '%s\n' "''${sorted_active[@]}" | sort -n)); unset IFS

        i=1
        for entry in "''${sorted_active[@]}"; do
          ws="''${entry%% *}"
          rdp="''${entry#* }"
          geom="''${rdp_geom[$rdp]}"
          w="''${geom%%x*}"; rest="''${geom#*x}"
          h="''${rest%%+*}"; rest="''${rest#*+}"
          x="''${rest%%+*}"; y="''${rest#*+}"

          log "enable X11-$i (''${w}x''${h}) for $rdp, workspace $ws"
          if ! swaymsg output "X11-$i" enable mode "''${w}x''${h}"; then
            log "ERROR: failed to enable X11-$i"
          fi
          swaymsg workspace "$ws" output "X11-$i" || true

          wid_idx=$((i - 1))
          if [ "$wid_idx" -lt "''${#wids[@]}" ]; then
            DISPLAY="$XRDP_XDISPLAY" xdotool windowsize "''${wids[$wid_idx]}" "$w" "$h" || true
            DISPLAY="$XRDP_XDISPLAY" xdotool windowmove "''${wids[$wid_idx]}" "$x" "$y" || true
          fi

          i=$((i + 1))
        done
        # Force swaybg to restart so it only creates surfaces for active outputs
        # (during sway reload, swaybg creates surfaces for all 6 default outputs)
        pkill -x swaybg || true

        log "configuration complete"
      }

      # Wait for sway to create all X11 outputs before first configure
      wait_for_outputs || true
      configure

      # Watch for RandR changes (monitors added/removed) and reconfigure
      DISPLAY="$XRDP_XDISPLAY" xev -root -event randr 2>/dev/null | while read -r line; do
        if [[ "$line" == *"RRScreenChangeNotify"* ]]; then
          log "RandR change detected, reconfiguring..."
          configure
        fi
      done
    '';
  };

  clipbridge = pkgs.writeShellApplication {
    name = "clipbridge-xrdp";
    runtimeInputs = [ pkgs.coreutils pkgs.xclip pkgs.wl-clipboard pkgs.clipnotify clipW2X ];
    text = ''
      [ -z "''${XRDP_XDISPLAY:-}" ] && exit 0
      rm -f /tmp/.clipbridge-last

      # Wayland → X11 (copy in Linux → paste in Windows)
      wl-paste --watch clip-w2x "$XRDP_XDISPLAY" &

      # X11 → Wayland (copy in Windows → paste in Linux)
      while DISPLAY="$XRDP_XDISPLAY" clipnotify; do
        CONTENT=$(xclip -selection clipboard -display "$XRDP_XDISPLAY" -o 2>/dev/null) || true
        LAST=$(cat /tmp/.clipbridge-last 2>/dev/null) || true
        if [ -n "$CONTENT" ] && [ "$CONTENT" != "$LAST" ]; then
          printf '%s' "$CONTENT" > /tmp/.clipbridge-last
          printf '%s' "$CONTENT" | wl-copy
        fi
      done
    '';
  };
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
      path = "ms0qptyr.default";

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
    signing = {
      key = "7725287258F052EE45294FA428CBDAAB3BBD8D9D";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Holden Rohrer";
        email = "hr@hrhr.dev";
      };
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
    pinentry.package = pkgs.wayprompt;
    # Optional: tweak cache TTLs (uncomment to use)
    # defaultCacheTtl = 1800;
    # maxCacheTtl = 7200;
    # enableSshSupport = true;
  };

  # Packages useful in the graphical (Wayland/Sway) environment
  home.packages = with pkgs; [
    screenshot
    openUrl
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

  systemd.user.services.xrdp-multimon = {
    Unit = {
      Description = "xrdp multi-monitor layout manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${lib.getExe xrdpMultimon}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.clipbridge-xrdp = {
    Unit = {
      Description = "Clipboard bridge between Wayland and xrdp X11";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${lib.getExe clipbridge}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.url-watcher = {
    Unit = {
      Description = "Watch for URL file drops from Windows and open in Firefox";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${lib.getExe urlWatcher}";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
      "--replace" "@SWAY_EXIT@" "${if hostConfig.hostname == "work" then "# sway exit disabled under xrdp (breaks session)" else "bindsym $mod+Shift+e exit"}"
    ];
  };
}
