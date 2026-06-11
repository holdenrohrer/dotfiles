#!/usr/bin/env bash
# ticket-audit: weekly evidence-based audit of ticket.org via headless
# claude. Backs up the file, lets claude cross-reference open items
# against reality (gh PRs, git logs), apply conclusive updates, and
# write a report. The ticket-yell SessionStart hook dead-man-switches
# this via the audit-last-run stamp.
set -euo pipefail

TICKET_FILE="${TICKET_FILE:-$HOME/projects/ticket.org}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/ticket-watch}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

# Don't let our own headless session trip (or consume) the yell hook
export TICKET_YELL_DISABLE=1

[ -r "$TICKET_FILE" ] || { echo "no ticket file at $TICKET_FILE" >&2; exit 1; }
mkdir -p "$STATE_DIR/backups"

# Backup, keep the 12 most recent
cp "$TICKET_FILE" "$STATE_DIR/backups/ticket-$(date +%F-%H%M%S).org"
ls -t "$STATE_DIR/backups"/ticket-*.org | tail -n +13 | xargs -r rm --

prompt=$(cat <<EOF
You are the weekly ticket auditor. Audit the org-mode ticket file at
$TICKET_FILE against evidence, without asking the user anything.

For each open item (TODO / PLANNING / BLOCKED):
1. Look for evidence of completion or unblocking. Evidence sources:
   - 'gh pr list' / 'gh pr view' / 'gh search prs' in the relevant repos
     (work repos live under $PROJECTS_DIR; check git remotes to find them)
   - git log in those repos for merge/feature commits matching the item
   - BLOCKER properties name their dependency (PR:..., EXT:..., INT:...)
2. If evidence is CONCLUSIVE that an item is done or its blocker cleared,
   edit the file: change the heading keyword, and add a properly aligned
   state-change line in the item body matching the file's existing style:
   - State "DONE"       from "BLOCKED"    [$(date '+%Y-%m-%d %a %H:%M')]
   followed by a short indented note of the evidence (e.g. "auditor: PR #42
   merged 2026-05-20"). NEVER delete items or prose, only update states.
3. If evidence is suggestive but not conclusive, do NOT edit; list it in
   your report as a question for the user.
4. Leave genuinely-still-open items untouched.

End with a report in this exact format:
## Audit report $(date +%F)
### Auto-closed (evidence)
- <item>: <evidence>
### Needs human answer
- <item>: <what the evidence hints, what to confirm>
### Still open, looks legitimate
- <count> items

Keep the report under 30 lines. Your final message is saved verbatim as
the report file.
EOF
)

report=$(timeout 20m claude -p "$prompt" \
  --allowedTools "Read,Glob,Grep,Edit,Bash(gh:*),Bash(git:*),Bash(git -C:*)")

echo "$report" > "$STATE_DIR/last-report.md"
date +%s > "$STATE_DIR/audit-last-run"
echo "$report"
