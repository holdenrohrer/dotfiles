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

  clipToWin = pkgs.writeShellApplication {
    name = "clip-to-win";
    runtimeInputs = [ pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      [ -z "''${XRDP_XDISPLAY:-}" ] && exit 0
      wl-paste | xclip -selection clipboard -display "$XRDP_XDISPLAY"
    '';
  };

  clipToLinux = pkgs.writeShellApplication {
    name = "clip-to-linux";
    runtimeInputs = [ pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      [ -z "''${XRDP_XDISPLAY:-}" ] && exit 0
      xclip -selection clipboard -display "$XRDP_XDISPLAY" -o | wl-copy
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

        # 6. Save state (only active entries, prevents stale accumulation)
        : > "$STATE_FILE"
        for rdp in "''${!ws_map[@]}"; do
          echo "$rdp=''${ws_map[$rdp]}" >> "$STATE_FILE"
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
          swaymsg "workspace $ws, move workspace to output X11-$i" || true

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

  # --- Wallpaper control: rotating ~/bg collection + Wallhaven refill ---
  # Everything hangs off the ~/bg/sc symlink ("sc" = "current"), which
  # sway.config and swaylock already read. bg-set repoints it and re-renders.
  bgSet = pkgs.writeShellApplication {
    name = "bg-set";
    runtimeInputs = [ pkgs.sway pkgs.jq pkgs.coreutils pkgs.findutils ];
    text = ''
      # bg-set <image>: set <image> as wallpaper on every ACTIVE output.
      # Per-active-output (never '*') to dodge the swaybg phantom-output
      # orphaned-surface bug on this xrdp multimon setup.
      img="$(readlink -f "$1")"
      [ -f "$img" ] || { echo "bg-set: no such file: $1" >&2; exit 1; }
      export SWAYSOCK
      SWAYSOCK="''${SWAYSOCK:-$(find /run/user/1000 -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit 2>/dev/null)}"
      [ -n "$SWAYSOCK" ] || { echo "bg-set: no sway socket (not in a graphical session)"; exit 0; }
      mkdir -p "$HOME/bg"
      ln -sfn "$img" "$HOME/bg/sc"
      for out in $(swaymsg -t get_outputs | jq -r '.[] | select(.active) | .name'); do
        swaymsg output "$out" bg "$img" fill >/dev/null
      done
      echo "bg-set: $img"
    '';
  };

  bgCycle = pkgs.writeShellApplication {
    name = "bg-cycle";
    runtimeInputs = [ pkgs.coreutils bgSet ];
    text = ''
      # bg-cycle: pick a random image from ~/bg, avoiding the last N shown.
      # History of resolved paths lives in ~/bg/.recent (newest last). N
      # defaults to half the collection (override with BG_AVOID_N), capped at
      # count-1 so there is always at least one candidate to choose from.
      shopt -s nullglob
      imgs=("$HOME"/bg/*.jpg "$HOME"/bg/*.jpeg "$HOME"/bg/*.png)
      count="''${#imgs[@]}"
      [ "$count" -gt 0 ] || { echo "bg-cycle: no images in ~/bg" >&2; exit 1; }

      recent="$HOME/bg/.recent"
      n="''${BG_AVOID_N:-$(( count / 2 ))}"
      [ "$n" -lt 1 ] && n=1
      [ "$n" -gt "$(( count - 1 ))" ] && n=$(( count - 1 ))

      # Set of paths to avoid: the last N shown plus the current wallpaper.
      declare -A avoid=()
      if [ -f "$recent" ]; then
        while IFS= read -r line; do [ -n "$line" ] && avoid["$line"]=1; done < "$recent"
      fi
      cur="$(readlink -f "$HOME/bg/sc" 2>/dev/null || true)"
      [ -n "$cur" ] && avoid["$cur"]=1

      # Candidates = images not in the avoid set; fall back to "anything but
      # the current one" if the history somehow swallowed everything.
      candidates=()
      for f in "''${imgs[@]}"; do
        rf="$(readlink -f "$f")"
        [ -z "''${avoid[$rf]:-}" ] && candidates+=("$f")
      done
      if [ "''${#candidates[@]}" -eq 0 ]; then
        for f in "''${imgs[@]}"; do
          [ "$(readlink -f "$f")" != "$cur" ] && candidates+=("$f")
        done
      fi
      [ "''${#candidates[@]}" -gt 0 ] || candidates=("''${imgs[@]}")

      pick="''${candidates[RANDOM % ''${#candidates[@]}]}"

      # Record the pick and keep only the last N entries of history.
      { [ -f "$recent" ] && cat "$recent"; readlink -f "$pick"; } \
        | tail -n "$n" > "$recent.tmp" && mv "$recent.tmp" "$recent"

      exec bg-set "$pick"
    '';
  };

  bgAdd = pkgs.writeShellApplication {
    name = "bg-add";
    runtimeInputs = [ pkgs.coreutils bgSet ];
    text = ''
      # bg-add: copy the current wallpaper into ~/bg (if new) and adopt the copy.
      cur="$(readlink -f "$HOME/bg/sc" 2>/dev/null || true)"
      [ -f "$cur" ] || { echo "bg-add: no current wallpaper" >&2; exit 1; }
      case "$cur" in "$HOME"/bg/*) echo "bg-add: already in ~/bg"; exit 0 ;; esac
      dest="$HOME/bg/$(basename "$cur")"
      cp -n "$cur" "$dest"
      echo "bg-add: added $(basename "$cur")"
      exec bg-set "$dest"
    '';
  };

  bgFetch = pkgs.writeShellApplication {
    name = "bg-fetch";
    runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils bgSet ];
    text = ''
      # bg-fetch [query]: download an on-style >=1920x1200 SFW wallpaper from
      # Wallhaven and set it. With no arg, picks a random search from the taste
      # profile below. Sorts by all-time favorites (curated quality, not the
      # random-junk slot machine) and picks a random image from a random early
      # page for variety.
      cache="$HOME/.cache/wallpaper"; mkdir -p "$cache"

      # Taste profile — Holden's vibes. Edit freely (rebuild only, no reload).
      tastes=(
        nature landscape mountains forest waterfall ocean desert
        animals wildlife birds cat
        pattern geometric psychedelic fractal trippy kaleidoscope
        crowd festival concert
        planet space nebula galaxy aurora moon
        macos abstract gradient minimal
      )
      q="''${1:-''${tastes[RANDOM % ''${#tastes[@]}]}}"
      enc="$(printf '%s' "$q" | jq -sRr @uri)"
      base="https://wallhaven.cc/api/v1/search?q=$enc&sorting=favorites&atleast=1920x1200&purity=100&categories=101"

      # random early page for variety; fall back to page 1 for thin tags
      page=$(( (RANDOM % 3) + 1 ))
      json="$(curl -sS --max-time 20 "$base&page=$page")"
      count="$(jq -r '.data | length' <<<"$json")"
      if [ "$count" -eq 0 ]; then
        json="$(curl -sS --max-time 20 "$base&page=1")"
        count="$(jq -r '.data | length' <<<"$json")"
      fi
      [ "$count" -gt 0 ] || { echo "bg-fetch: no results for '$q'" >&2; exit 1; }

      idx=$(( RANDOM % count ))
      url="$(jq -r ".data[$idx].path" <<<"$json")"
      id="$(jq -r ".data[$idx].id" <<<"$json")"
      out="$cache/wallhaven-$id.''${url##*.}"
      curl -sS --max-time 60 -o "$out" "$url"
      echo "bg-fetch: '$q' -> $id"
      exec bg-set "$out"
    '';
  };

  # Centered Wayland launcher (bemenu-run + flags). Wrapped in a script so the
  # sway keybind can call the bare name `menu-run` — flag tweaks then need only
  # a rebuild, never a sway reload.
  menuRun = pkgs.writeShellApplication {
    name = "menu-run";
    runtimeInputs = [ pkgs.bemenu ];
    text = ''exec bemenu-run -c -i -l 10 -W 0.3 "$@"'';
  };

  # $mod+f: send the focused window to a fresh empty workspace and follow it.
  # Replaces `fullscreen toggle` — fullscreening a grabbing Xwayland window
  # (ssh-askpass et al.) wedged keyboard input. Target = lowest positive
  # workspace number that doesn't yet exist, so it's guaranteed empty.
  boomToEmpty = pkgs.writeShellApplication {
    name = "boom-to-empty";
    runtimeInputs = [ pkgs.sway pkgs.jq pkgs.coreutils pkgs.findutils ];
    text = ''
      SWAYSOCK="''${SWAYSOCK:-$(find /run/user/"$(id -u)" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit 2>/dev/null)}"
      export SWAYSOCK
      used="$(swaymsg -t get_workspaces | jq '[.[].num] | map(select(. > 0))')"
      n=1
      while jq -e --argjson n "$n" 'index($n) != null' <<<"$used" >/dev/null; do
        n=$((n + 1))
      done
      swaymsg "move container to workspace number $n; workspace number $n" >/dev/null
    '';
  };

  bgMenu = pkgs.writeShellApplication {
    name = "bg-menu";
    # bemenu (Wayland-native, centered via -c) — plain dmenu is X11 and can't
    # open a display under this xrdp/sway session, so it would fail silently.
    runtimeInputs = [ pkgs.coreutils pkgs.bemenu bgCycle bgFetch bgAdd bgSet ];
    text = ''
      # bg-menu: bemenu front-end for wallpaper control (bound to a sway key).
      # Fixed order + stable numbers so 1–5 are reliable muscle memory. The
      # save entry is always shown; bg-add is a no-op if it's already saved.
      raw=(
        "🎲 Cycle now (random from ~/bg)"
        "🌐 Fetch fresh (my style)"
        "🔍 Fetch by search…"
        "💾 Save current to ~/bg"
        "🖼 Pick from ~/bg…"
      )
      opts=(); i=1
      for o in "''${raw[@]}"; do opts+=( "$i  $o" ); i=$((i + 1)); done
      choice="$(printf '%s\n' "''${opts[@]}" | bemenu -c -i -l 10 -W 0.25 -p 'wallpaper')" || exit 0
      case "$choice" in
        *🎲*) exec bg-cycle ;;
        *🌐*) exec bg-fetch ;;
        *🔍*)
          term="$(bemenu -c -W 0.25 -p 'search Wallhaven:' < /dev/null)" || exit 0
          [ -n "$term" ] && exec bg-fetch "$term" ;;
        *💾*) exec bg-add ;;
        *🖼*)
          shopt -s nullglob; cd "$HOME/bg"
          files=(*.jpg *.jpeg *.png)
          pick="$(printf '%s\n' "''${files[@]}" | bemenu -c -i -l 15 -W 0.25 -p 'pick bg')" || exit 0
          [ -n "$pick" ] && exec bg-set "$HOME/bg/$pick" ;;
      esac
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
      path = if hostConfig.hostname == "personal" then "ms0qptyr.default" else "default";

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
      init.defaultBranch = "master";
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
    bgMenu    # $mod+Shift+w — on PATH so the keybind is a stable bare name
    menuRun   # $mod+space   — ditto (keeps sway.config static → no reloads)
    boomToEmpty # $mod+f     — ditto
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

  systemd.user.services.wallpaper-cycle = {
    Unit = {
      Description = "Rotate wallpaper from the ~/bg collection";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe bgCycle}";
    };
  };

  systemd.user.timers.wallpaper-cycle = {
    Unit.Description = "Rotate wallpaper daily (and catch up on login if missed)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
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
      "--replace" "@clipToWin@" "${lib.getExe clipToWin}"
      "--replace" "@clipToLinux@" "${lib.getExe clipToLinux}"
      "--replace" "@SWAY_EXIT@" "${if hostConfig.hostname == "work" then "# sway exit disabled under xrdp (breaks session)" else "bindsym $mod+Shift+e exit"}"
    ];
  };

  # Reload the running sway ONLY when its config genuinely changed this
  # generation. ~/.config/sway/config symlinks to a /nix/store path whose hash
  # changes iff the content changes — so comparing the resolved path against a
  # recorded baseline detects real config changes. Script/flag-only rebuilds
  # (bare-name keybinds → static sway.config) leave it untouched and reload
  # nothing, sparing the disruptive multi-monitor reshuffle.
  home.activation.reloadSwayOnConfigChange =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      swayCfg="$(readlink -f "${config.xdg.configHome}/sway/config" 2>/dev/null || true)"
      stateFile="${config.xdg.stateHome}/sway/loaded-config"
      prev="$(cat "$stateFile" 2>/dev/null || true)"
      if [ -n "$swayCfg" ] && [ "$swayCfg" != "$prev" ]; then
        # Skip the reload on the very first run (no baseline yet) so adopting
        # this hook doesn't itself trigger a spurious reshuffle.
        if [ -n "$prev" ]; then
          sock="$(find "/run/user/$(id -u)" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit 2>/dev/null || true)"
          if [ -n "$sock" ]; then
            $DRY_RUN_CMD env SWAYSOCK="$sock" ${pkgs.sway}/bin/swaymsg reload > /dev/null 2>&1 || true
          fi
        fi
        mkdir -p "$(dirname "$stateFile")"
        printf '%s\n' "$swayCfg" > "$stateFile"
      fi
    '';
}
