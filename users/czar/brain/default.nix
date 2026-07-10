# The magic box: surfaces onto the loom (~/brain), the shared append-only
# memory woven with fable. The loom repo carries its own spells in bin/;
# this module only summons them — a capture prompt on a sway keybind, and
# a local heartbeat so fable can weave until hermes takes over residence.
#
# ~/brain is a clone of gitolite brain.git (git.hrhr.dev) over the
# per-device brain-* deploy key; sync is best-effort and captures never
# block on the network. See ~/brain/BRAIN.md for the physics.
{ config, lib, pkgs, inputs, ... }:

let
  claude = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

  loom = "${config.home.homeDirectory}/brain";
  loomPath = lib.makeBinPath
    (with pkgs; [ bash coreutils gnugrep gnused git openssh util-linux systemd ]);

  # $mod+j — one line into the loom, then back to whatever you were doing.
  # The menu lines are views/box: the recent weave (plus fable's pinned pane),
  # so czar writes into visible shared context rather than a void.
  brain-box = pkgs.writeShellScriptBin "brain-box" ''
    export PATH="${loomPath}:$PATH"
    text="$(cat ${loom}/views/box 2>/dev/null | ${pkgs.bemenu}/bin/bemenu -c -i -l 16 -W 0.8 -p loom)" || exit 0
    [ -n "$text" ] || exit 0
    exec ${loom}/bin/brain-capture -s box "$text"
  '';

  # Usage observability for the Max account feeding the local heartbeat
  ccusage = pkgs.writeShellScriptBin "ccusage" ''
    exec ${pkgs.nodejs}/bin/npx -y ccusage@latest "$@"
  '';

  # Heartbeat wrapper: pure shell (a git pull) when nothing is unprocessed,
  # wakes fable (claude -p, Max subscription creds) when something is.
  brain-beat = pkgs.writeShellScriptBin "brain-beat" ''
    export PATH="${loomPath}:${claude}/bin:$PATH"
    exec ${loom}/bin/brain-think "$@"
  '';
in
{
  home.packages = [ brain-box brain-beat ccusage ];

  systemd.user.services.brain-think = {
    Unit.Description = "Loom heartbeat: fable weaves unprocessed entries";
    Service = {
      Type = "oneshot";
      ExecStart = "${brain-beat}/bin/brain-beat";
      # The auth door: subscription OAuth (~/.claude) by default; drop
      # ANTHROPIC_API_KEY into this file to flip to API billing. Optional.
      EnvironmentFile = "-%h/.config/brain/env";
    };
  };

  # Frequent because it is nearly free: only a sync unless captures await.
  # When hermes hosts the resident heartbeat, this stays as local reflex —
  # in-band re: marks keep the two brains from re-weaving the same entry.
  systemd.user.timers.brain-think = {
    Unit.Description = "Loom heartbeat";
    Timer = {
      OnBootSec = "3min";
      OnUnitInactiveSec = "5min";
      RandomizedDelaySec = "30s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
