{ pkgs, ... }:

let
  low-bat = pkgs.writeScriptBin "low-bat" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Return success if any mains power supply is online.
    ac_online() {
      for p in /sys/class/power_supply/*; do
        [ -f "$p/type" ] && [ "$(cat "$p/type")" = "Mains" ] || continue
        [ -f "$p/online" ] && [ "$(cat "$p/online")" = "1" ] && return 0
      done
      return 1
    }

    # Sum integers from files (fast via awk; skips missing).
    sum_files() {
      awk '{s+=$1} END{print s+0}' "$@"
    }

    # Composite battery per‑mille using design capacity (energy_* only).
    per_mille_design() {
      if compgen -G "/sys/class/power_supply/BAT*/energy_full_design" > /dev/null; then
        local full now
        full=$(sum_files /sys/class/power_supply/BAT*/energy_full_design)
        now=$(sum_files /sys/class/power_supply/BAT*/energy_now)
        if [ "$full" -gt 0 ]; then
          echo $(( (1000 * now) / full ))
          return
        fi
      fi
      echo 0
    }

    # Set all Caps Lock LEDs to 0/1 if present.
    set_caps_leds() {
      for led in /sys/class/leds/*::capslock; do
        [ -w "$led/brightness" ] && echo "$1" > "$led/brightness" || true
      done
    }

    main() {
      if ac_online; then
        set_caps_leds 0
        exit 0
      fi

      local pm
      pm=$(per_mille_design)  # integer (0 if unknown)
      echo "low-bat: $pm‰ remaining (design)"

      if [ "$pm" -le 10 ]; then        # <= 1%
        set_caps_leds 1
        echo "low-bat: critical -> hybrid-sleep"
        ${pkgs.systemd}/bin/systemctl hybrid-sleep
      elif [ "$pm" -le 50 ]; then      # <= 5%
        set_caps_leds 1
        echo "low-bat: warning"
      else
        set_caps_leds 0
      fi
    }

    main "$@"
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
