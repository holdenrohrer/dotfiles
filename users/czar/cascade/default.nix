# Clocks for the cascade (~/cascade, work host only).
#
# All logic lives in emacs (init.el, the czar/cascade-* functions):
# org-native, live-reloadable, testable via emacsclient -e. These units
# just poke the daemon on schedule:
#  - cascade-inbox:    07:55 weekdays — refresh the Inbox mail slot
#                      (Salesforce tickets + chatter; the only subtree
#                      machines may write), just ahead of...
#  - cascade-glance:   08:00 weekdays — notify the Today section
#  - cascade-snapshot: daily — copy sections at their cadence boundary
#                      into archive/ (a camera, not a broom)
#
# Persistent timers fire missed elapses at boot, so a late-started
# machine still gets its morning glance. If the daemon is down the poke
# fails into the journal and life goes on.
{ config, lib, ... }:

let
  emacsclient = "${config.programs.emacs.package}/bin/emacsclient";

  poke = desc: fn: cal: {
    service = {
      Unit = {
        Description = desc;
        After = [ "emacs.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = ''${emacsclient} -e "(${fn})"'';
      };
    };
    timer = {
      Unit.Description = "${desc} (timer)";
      Timer = {
        OnCalendar = cal;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # After cascade-inbox: only bites at boot catch-up, when Persistent
  # fires both at once — orders the refresh ahead of the knock.
  glance = lib.recursiveUpdate
    (poke "cascade: morning glance at Today" "czar/cascade-glance"
      "Mon..Fri 08:00")
    { service.Unit.After = [ "emacs.service" "cascade-inbox.service" ]; };
  inbox = poke "cascade: refresh Salesforce inbox mail slot" "czar/cascade-inbox-refresh"
    "Mon..Fri 07:55";
  snapshot = poke "cascade: cadence-boundary archive snapshot" "czar/cascade-snapshot"
    "07:30";
  # Unsigned machine snapshot commits; signed commits remain the mark of
  # a human ritual. Push is best-effort (journal on failure).
  commit = poke "cascade: daily unsigned auto-commit and push" "czar/cascade-commit"
    "Mon..Fri 17:30";
in
{
  systemd.user.services = {
    cascade-glance = glance.service;
    cascade-inbox = inbox.service;
    cascade-snapshot = snapshot.service;
    cascade-commit = commit.service;
  };
  systemd.user.timers = {
    cascade-glance = glance.timer;
    cascade-inbox = inbox.timer;
    cascade-snapshot = snapshot.timer;
    cascade-commit = commit.timer;
  };
}
