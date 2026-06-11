#!/usr/bin/env bash
# ticket-yell: Claude Code SessionStart hook. Always emits a compact
# header telling Claude about the `ticket` CLI (and to actively capture
# new work and niggles with it); additionally surfaces stale ticket.org
# items so Claude nags about them and can apply status updates the
# moment the user reports one. The nag is throttled to one yell per
# THROTTLE_HOURS so it never becomes wallpaper. Also dead-man-switches
# the weekly auditor.
set -euo pipefail

TICKET_FILE="${TICKET_FILE:-$HOME/projects/ticket.org}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/ticket-watch}"
STALE_DAYS="${STALE_DAYS:-14}"
DEADMAN_DAYS="${DEADMAN_DAYS:-10}"
THROTTLE_HOURS="${THROTTLE_HOURS:-20}"
MAX_ITEMS=8

# The auditor sets this so its own headless session isn't yelled at
# (and doesn't consume the daily yell budget).
[ "${TICKET_YELL_DISABLE:-0}" = 1 ] && exit 0

[ -r "$TICKET_FILE" ] || exit 0
mkdir -p "$STATE_DIR"

now=$(date +%s)

# Throttle the nag (not the header): at most one per THROTTLE_HOURS
nag=1
if [ "${FORCE:-0}" != 1 ] && [ -f "$STATE_DIR/last-yell" ]; then
  last=$(cat "$STATE_DIR/last-yell")
  if (( now - last < THROTTLE_HOURS * 3600 )); then
    nag=0
  fi
fi

# Emit "epoch<TAB>state<TAB>title" per open item; date = newest org timestamp
# in the item's body. Items with no timestamp at all are unageable — counted
# separately rather than guessed at (file mtime is a lie: any edit anywhere,
# including the auditor's own, would refresh every undated item at once).
items=$(awk '
  function flush() {
    if (title != "") print (best ? best : "undated") "\t" state "\t" title
  }
  /^\*+[ \t]+(TODO|PLANNING|BLOCKED)[ \t]/ {
    flush()
    state = $2
    title = $0
    sub(/^\*+[ \t]+(TODO|PLANNING|BLOCKED)[ \t]+/, "", title)
    sub(/^\[#[A-D]\][ \t]*/, "", title)
    best = ""
    next
  }
  /^\*+[ \t]/ { flush(); title = ""; next }  # heading without open state
  title != "" {
    line = $0
    while (match(line, /[<[][0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
      d = substr(line, RSTART + 1, 10)
      if (d > best) best = d
      line = substr(line, RSTART + RLENGTH)
    }
  }
  END { flush() }
' "$TICKET_FILE" | while IFS=$'\t' read -r d state title; do
  if [ "$d" = undated ]; then epoch=undated; else epoch=$(date -d "$d" +%s); fi
  echo -e "$epoch\t$state\t$title"
done)

stale=$(echo "$items" | awk -F'\t' -v now="$now" -v days="$STALE_DAYS" \
  '$1 != "undated" && now - $1 >= days * 86400 \
     { print int((now - $1) / 86400) "\t" $2 "\t" $3 }' \
  | sort -rn)

n_stale=$(grep -c . <<<"$stale" || true)
n_undated=$(echo "$items" | grep -c $'^undated\t' || true)

# Dead-man's switch on the weekly auditor
deadman=""
if [ ! -f "$STATE_DIR/audit-last-run" ]; then
  deadman="The ticket auditor has NEVER run."
else
  audit_age=$(( (now - $(cat "$STATE_DIR/audit-last-run")) / 86400 ))
  if (( audit_age >= DEADMAN_DAYS )); then
    deadman="The ticket auditor last ran ${audit_age} days ago — it may be dead. Suggest checking: systemctl --user status ticket-audit.timer"
  fi
fi

echo "<ticket-watchdog>"
cat <<EOF
The user tracks work in $TICKET_FILE (org-mode) via the \`ticket\` CLI:
  ticket list [open|all|STATE]   — open items with ages and blockers
  ticket show PATTERN            — full subtree of a matching heading
  ticket add TITLE [--state S --effort E --ticket SA-NNNNN --blocker B --parent PATTERN --note TEXT]
  ticket state PATTERN NEWSTATE [NOTE]
Actively capture work here: when the user mentions an ongoing project, a follow-up, or a little niggle that isn't tracked yet, add it with \`ticket add\` (no SA ticket needed — small annoyances belong here too, default parent is Unassigned). When the user reports a status ("oh that's done", "still waiting on X"), apply it immediately with \`ticket state\`.
EOF

if (( nag )) && { [ "$n_stale" -gt 0 ] || [ -n "$deadman" ]; }; then
  date +%s > "$STATE_DIR/last-yell"
  echo
  echo "STALE TICKET ALERT: $n_stale open item(s) with no activity in over $STALE_DAYS days:"
  echo "$stale" | head -n "$MAX_ITEMS" | awk -F'\t' '{ printf "- %s, %sd stale: %s\n", $2, $1, $3 }'
  if (( n_stale > MAX_ITEMS )); then
    echo "...and $((n_stale - MAX_ITEMS)) more."
  fi
  if (( n_undated > 0 )); then
    echo "Also: $n_undated open item(s) have no org timestamps at all (age unknowable). When touching these, add dated State lines so they become auditable."
  fi
  if [ -n "$deadman" ]; then echo "$deadman"; fi
  echo "At a natural moment (start of conversation, or after finishing the current task — never interrupting deep work mid-task), nag the user about the stalest of these. Be direct; the user has asked to be yelled at about ticket rot. If the user is clearly mid-task, a single short mention is enough."
fi
echo "</ticket-watchdog>"
