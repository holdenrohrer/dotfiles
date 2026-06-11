#!/usr/bin/env bash
# ticket: small CLI over ~/projects/ticket.org so Claude (and the user)
# can list, inspect, add, and update items without reading the whole file.
#
#   ticket list [open|all|TODO|PLANNING|BLOCKED|DONE]
#   ticket show PATTERN
#   ticket add TITLE [--state S] [--effort E] [--ticket SA-NNNNN]
#                    [--blocker B] [--parent PATTERN] [--note TEXT]
#   ticket state PATTERN NEWSTATE [NOTE]
#
# PATTERN matches heading text case-insensitively and must be unique
# (for show, multiple matches are all shown). New items default to
# state TODO under the "Unassigned" heading; little niggles without an
# SA ticket are welcome — that's what Unassigned is for.
set -euo pipefail

TICKET_FILE="${TICKET_FILE:-$HOME/projects/ticket.org}"
KEYWORDS='TODO|PLANNING|BLOCKED|DONE'

now_org() { date '+%Y-%m-%d %a %H:%M'; }

state_line() {  # state_line NEWSTATE OLDSTATE
  local from=""
  [ -n "${2:-}" ] && from="\"$2\""
  printf -- '- State %-12s from %-12s [%s]' "\"$1\"" "$from" "$(now_org)"
}

die() { echo "ticket: $*" >&2; exit 1; }

[ -r "$TICKET_FILE" ] || die "no ticket file at $TICKET_FILE"

# Find heading lines matching PATTERN (case-insensitive substring).
# Prints "lineno<TAB>heading" per match.
find_headings() {
  awk -v pat="$(echo "$1" | tr '[:upper:]' '[:lower:]')" '
    /^\*+[ \t]/ && index(tolower($0), pat) { print NR "\t" $0 }
  ' "$TICKET_FILE"
}

require_unique() {  # require_unique PATTERN -> sets MATCH_LINE, MATCH_TEXT
  local matches; matches=$(find_headings "$1")
  local n; n=$(grep -c . <<<"$matches" || true)
  [ "$n" -eq 0 ] && die "no heading matches '$1'"
  if [ "$n" -gt 1 ]; then
    echo "ticket: pattern '$1' is ambiguous:" >&2
    cut -f2 <<<"$matches" >&2
    exit 1
  fi
  MATCH_LINE=$(cut -f1 <<<"$matches")
  MATCH_TEXT=$(cut -f2 <<<"$matches")
}

cmd_list() {
  local filter="${1:-open}"
  awk -v kw="$KEYWORDS" -v filter="$filter" '
    function flush() {
      if (state == "") return
      show = (filter == "all") \
          || (filter == "open" && state != "DONE") \
          || (state == filter)
      if (!show) return
      age = "?"
      if (best != "") {
        split(best, p, "-")
        age = int((systime() - mktime(p[1] " " p[2] " " p[3] " 0 0 0")) / 86400) "d"
      }
      printf "%-9s %5s  %-9s %s%s\n", state, age, ticket, title, \
        (blocker != "" ? "  [blocked-by " blocker "]" : "")
    }
    $0 ~ "^\\*+[ \t]+(" kw ")[ \t]" {
      flush()
      state = $2
      title = $0
      sub("^\\*+[ \t]+(" kw ")[ \t]+", "", title)
      sub(/^\[#[A-D]\][ \t]*/, "", title)
      best = ""; ticket = ""; blocker = ""
      next
    }
    /^\*+[ \t]/ { flush(); state = "" ; next }
    state != "" {
      if (match($0, /:TICKET:[ \t]+[^ \t]+/)) {
        ticket = substr($0, RSTART, RLENGTH); sub(/:TICKET:[ \t]+/, "", ticket)
      }
      if (match($0, /:BLOCKER:[ \t]+[^ \t]+/)) {
        blocker = substr($0, RSTART, RLENGTH); sub(/:BLOCKER:[ \t]+/, "", blocker)
      }
      line = $0
      while (match(line, /[<[][0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        d = substr(line, RSTART + 1, 10)
        if (d > best) best = d
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { flush() }
  ' "$TICKET_FILE"
}

cmd_show() {
  [ $# -ge 1 ] || die "usage: ticket show PATTERN"
  local matches; matches=$(find_headings "$1")
  [ -n "$matches" ] || die "no heading matches '$1'"
  while IFS=$'\t' read -r lineno _; do
    awk -v start="$lineno" '
      NR == start { match($0, /^\*+/); lvl = RLENGTH; print; next }
      NR > start {
        if (match($0, /^\*+/) && RLENGTH <= lvl) exit
        print
      }
    ' "$TICKET_FILE"
  done <<<"$matches"
}

cmd_add() {
  [ $# -ge 1 ] || die "usage: ticket add TITLE [--state S] [--effort E] [--ticket T] [--blocker B] [--parent PATTERN] [--note TEXT]"
  local title="$1"; shift
  local state=TODO effort="" ticketid="" blocker="" parent="Unassigned" note=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --state)   state="$2"; shift 2 ;;
      --effort)  effort="$2"; shift 2 ;;
      --ticket)  ticketid="$2"; shift 2 ;;
      --blocker) blocker="$2"; shift 2 ;;
      --parent)  parent="$2"; shift 2 ;;
      --note)    note="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  grep -Eq "^($KEYWORDS)$" <<<"$state" || die "bad state: $state"

  require_unique "$parent"
  local plvl; plvl=$(grep -oE '^\*+' <<<"$MATCH_TEXT" | tr -d '\n' | wc -c)
  local stars; stars=$(printf '%*s' $((plvl + 1)) '' | tr ' ' '*')
  local indent; indent=$(printf '%*s' $((plvl + 2)) '')

  # End of parent subtree: line before next heading of level <= parent
  local end; end=$(awk -v start="$MATCH_LINE" -v lvl="$plvl" '
    NR > start && match($0, /^\*+/) && RLENGTH <= lvl { print NR - 1; found = 1; exit }
    END { if (!found) print NR }
  ' "$TICKET_FILE")

  local entry="$stars $state $title"$'\n'
  if [ -n "$effort$ticketid$blocker" ]; then
    entry+="$indent:PROPERTIES:"$'\n'
    [ -n "$ticketid" ] && entry+="$indent:TICKET:   $ticketid"$'\n'
    [ -n "$effort" ]   && entry+="$indent:Effort:   $effort"$'\n'
    [ -n "$blocker" ]  && entry+="$indent:BLOCKER:  $blocker"$'\n'
    entry+="$indent:END:"$'\n'
  fi
  entry+="$indent$(state_line "$state")"$'\n'
  if [ -n "$note" ]; then entry+="$indent$note"$'\n'; fi

  local tmp; tmp=$(mktemp)
  { head -n "$end" "$TICKET_FILE"; printf '%s' "$entry"; tail -n +"$((end + 1))" "$TICKET_FILE"; } > "$tmp"
  mv "$tmp" "$TICKET_FILE"
  echo "added under '$MATCH_TEXT':"
  printf '%s' "$entry"
}

cmd_state() {
  [ $# -ge 2 ] || die "usage: ticket state PATTERN NEWSTATE [NOTE]"
  local pattern="$1" newstate="$2" note="${3:-}"
  grep -Eq "^($KEYWORDS)$" <<<"$newstate" || die "bad state: $newstate"
  require_unique "$pattern"

  local tmp; tmp=$(mktemp)
  awk -v target="$MATCH_LINE" -v kw="$KEYWORDS" -v newstate="$newstate" \
      -v sline_tmpl="__STATE_LINE__" -v note="$note" '
    NR == target {
      match($0, /^\*+/); lvl = RLENGTH
      old = ""
      if (match($0, "^\\*+[ \t]+(" kw ")[ \t]")) {
        old = $2
        sub("^(\\*+[ \t]+)(" kw ")", substr($0, 1, lvl) " " newstate)
      } else {
        sub(/^\*+/, substr($0, 1, lvl) " " newstate)
      }
      print
      oldstate = old
      pending = 1
      indent = sprintf("%*s", lvl + 1, "")
      next
    }
    pending {
      # skip past a properties drawer before inserting the state line
      if (!inserted && $0 ~ /^[ \t]*:(PROPERTIES|[A-Za-z_]+):/ ) { print; next }
      if (!inserted && $0 ~ /^[ \t]*:END:/) { print; insert_now = 1; next }
      if (!inserted) insert_now = 1
      if (insert_now) {
        print indent sline_tmpl
        if (note != "") print indent "  " note
        inserted = 1; insert_now = 0; pending = 0
      }
      print
      next
    }
    { print }
    END { if (pending && !inserted) { print indent sline_tmpl; if (note != "") print indent "  " note } }
  ' "$TICKET_FILE" > "$tmp"

  # Splice in the real state line (awk above marked the spot)
  local old; old=$(grep -oE "^\*+[ \t]+($KEYWORDS)" <<<"$MATCH_TEXT" | awk '{print $2}' || true)
  sed -i "s/__STATE_LINE__/$(state_line "$newstate" "$old" | sed 's/[&/\]/\\&/g')/" "$tmp"
  mv "$tmp" "$TICKET_FILE"
  echo "updated: $MATCH_TEXT -> $newstate"
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list)  cmd_list "$@" ;;
  show)  cmd_show "$@" ;;
  add)   cmd_add "$@" ;;
  state) cmd_state "$@" ;;
  *) die "unknown command: $cmd (try list|show|add|state)" ;;
esac
