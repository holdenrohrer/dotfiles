{ pkgs, ... }:

let
  low-bat = pkgs.writeScriptBin "low-bat" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    on_ac() {
      for p in /sys/class/power_supply/*; do
        if [ -f "$p/type" ] && [ "$(cat "$p/type")" = "Mains" ] && \
           [ -f "$p/online" ] && [ "$(cat "$p/online")" = "1" ]; then
          return 0
        fi
      done
      return 1
    }

    sum() { awk '{s+=$1} END{print s+0}' "$@"; }

    per_mille_design() {
      local full now
      if ls /sys/class/power_supply/BAT*/energy_full_design >/dev/null 2>&1; then
        full=$(sum /sys/class/power_supply/BAT*/energy_full_design)
        now=$(sum /sys/class/power_supply/BAT*/energy_now)
      elif ls /sys/class/power_supply/BAT*/charge_full_design >/dev/null 2>&1; then
        full=$(sum /sys/class/power_supply/BAT*/charge_full_design)
        now=$(sum /sys/class/power_supply/BAT*/charge_now)
      else
        echo 0; return
      fi
      [ "${full:-0}" -gt 0 ] || { echo 0; return; }
      echo $(( (1000 * now) / full ))
    }

    set_caps_led() {
      local v="$1"
      for led in /sys/class/leds/*::capslock; do
        [ -e "$led/brightness" ] && echo "$v" > "$led/brightness" 2>/dev/null || true
      done
    }

    pm=$(per_mille_design)

    if on_ac; then
      set_caps_led 0
      exit 0
    fi

    if [ "$pm" -le 10 ] 2>/dev/null; then
      set_caps_led 1
      echo "low-bat: ${pm}‰ -> hybrid-sleep" | ${pkgs.systemd}/bin/systemd-cat -t low-bat -p info
      ${pkgs.systemd}/bin/systemctl hybrid-sleep
    elif [ "$pm" -le 50 ] 2>/dev/null; then
      set_caps_led 1
      echo "low-bat: warning ${pm}‰" | ${pkgs.systemd}/bin/systemd-cat -t low-bat -p info
    else
      set_caps_led 0
    fi
  '';
in {
  environment.systemPackages = [ low-bat ];

  systemd.services.low-bat-check = {
    description = "Low battery check (design-based)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${low-bat}/bin/low-bat";
    };
  };

  systemd.timers.low-bat-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
    };
  };
}
