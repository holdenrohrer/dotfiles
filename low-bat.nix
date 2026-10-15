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
      ${pkgs.gawk}/bin/awk '{s+=$1} END{print s+0}' "$@"
    }

    # Composite battery per‑mille using design capacity. Batteries report
    # either energy_* (µWh, e.g. ThinkPad) or charge_* (µAh, e.g. Framework);
    # use whichever family is present. Prints nothing if neither is readable,
    # so "unknown" can never be mistaken for "empty".
    per_mille_design() {
      local unit full now
      for unit in energy charge; do
        compgen -G "/sys/class/power_supply/BAT*/''${unit}_full_design" > /dev/null || continue
        full=$(sum_files /sys/class/power_supply/BAT*/''${unit}_full_design)
        now=$(sum_files /sys/class/power_supply/BAT*/''${unit}_now)
        if [ "$full" -gt 0 ]; then
          echo $(( (1000 * now) / full ))
          return
        fi
      done
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
      pm=$(per_mille_design)
      if [ -z "$pm" ]; then
        echo "low-bat: no readable battery capacity; doing nothing" >&2
        exit 1
      fi
      printf 'low-bat: %s‰ remaining (design)\n' "$pm"

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
  systemd.services.low-bat-check = {
    description = "Low battery check (design-based)";
    serviceConfig = {
      Type = "oneshot";
      SyslogIdentifier = "low-bat";
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

  services.udev.extraRules = ''
    # Trigger when AC mains goes online; have systemd run our check.
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="add|change", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="low-bat-check.service"
  '';
}
