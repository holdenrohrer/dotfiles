# Anti-entropy watchdog for ~/projects/ticket.org (work host only).
#
# Three parts, watching each other:
#  - ticket: small CLI (list/show/add/state) so Claude and the user can
#    work with items without reading the whole file. Claude is told to
#    actively capture new projects and little niggles with it.
#  - ticket-yell: SessionStart hook that teaches every Claude session
#    the CLI and surfaces stale open items (nag throttled to ~daily),
#    so Claude nags and applies status updates in-conversation.
#  - ticket-audit: weekly systemd timer running headless claude to
#    cross-reference open items against evidence (gh PRs, git logs) and
#    update the file itself; ticket-yell raises an alarm if this timer
#    ever silently dies.
{ config, lib, pkgs, inputs, ... }:

let
  claude = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Strip shebang from source scripts since writeShellScriptBin adds its own
  stripShebang = file:
    builtins.concatStringsSep "\n"
      (builtins.tail (lib.splitString "\n" (builtins.readFile file)));

  yellPath = lib.makeBinPath (with pkgs; [ coreutils gnugrep gawk ]);
  cliPath = lib.makeBinPath (with pkgs; [ coreutils gnugrep gawk gnused ]);
  auditPath = lib.makeBinPath
    ([ claude ] ++ (with pkgs; [ coreutils findutils gnugrep gawk git gh ]));

  ticket-cli = pkgs.writeShellScriptBin "ticket" ''
    export PATH="${cliPath}:$PATH"
    ${stripShebang ./ticket-cli.sh}
  '';

  ticket-yell = pkgs.writeShellScriptBin "ticket-yell" ''
    export PATH="${yellPath}:$PATH"
    ${stripShebang ./ticket-yell.sh}
  '';

  ticket-audit = pkgs.writeShellScriptBin "ticket-audit" ''
    export PATH="${auditPath}:$PATH"
    ${stripShebang ./ticket-audit.sh}
  '';
in
{
  # On PATH: `ticket` for everyday use, `ticket-audit` for an
  # off-schedule audit, `FORCE=1 ticket-yell` to preview the current nag.
  home.packages = [ ticket-cli ticket-yell ticket-audit ];

  claude.hooks.SessionStart = [{
    hooks = [{
      type = "command";
      command = "${ticket-yell}/bin/ticket-yell";
    }];
  }];

  systemd.user.services.ticket-audit = {
    Unit.Description = "Evidence-based audit of ticket.org via headless claude";
    Service = {
      Type = "oneshot";
      ExecStart = "${ticket-audit}/bin/ticket-audit";
    };
  };

  systemd.user.timers.ticket-audit = {
    Unit.Description = "Weekly ticket.org audit";
    Timer = {
      OnCalendar = "Mon 09:30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
