---
name: work
description: Start, resume, check on, or finish a unit of work — one bead, one branch, one worktree. Use at the start of any code change in ~/projects/<repo>, when asked to pick up or finish a task, or whenever you notice you're about to edit a trunk checkout.
---

# /work — one bead, one branch, one worktree

**Invariant.** The *branch* is the durable object. A *worktree* is a disposable
cache of a branch. Anything uncommitted doesn't exist. `~/projects/<repo>` is the
trunk checkout and is never edited.

## Vocabulary

| thing | where | rule |
|---|---|---|
| trunk checkout | `~/projects/<repo>` | always on the default branch, always clean; `br` runs here |
| bead | `br` issue, ID `<prefix>-<slug>-<hash>` | names the branch and the worktree |
| worktree | `~/projects/<repo>/.claude/worktrees/<bead-id>` | branch `<bead-id>`, removed on finish |

Never create sibling clones (`~/projects/<repo>-<feature>`); that layout is retired.
Never give subagents `isolation: worktree`; they work in this worktree or read-only.

## `/work [<repo>] [<bead-id> | "<title>"]` — start or resume

0. Infer what's omitted: if cwd is inside a repo, that's `<repo>`; if cwd is
   inside `.claude/worktrees/<id>`, that's the bead — you're resuming, skip to 6.
1. `cd ~/projects/<repo>`; require `git status --porcelain` empty. If not,
   **stop and show the user** — trunk dirt means the protocol was broken
   upstream, and absorbing it silently is how the sprawl came back last time.
2. No `.beads/`? `br init --prefix <short>`. It's globally gitignored — never
   commit it, never `git add -f` it; beads are the user's queue, not the repo's.
3. Resolve the bead: an ID → `br show <id>`; a title →
   `br create "<title>" --slug <kebab-slug> -t task`; nothing → `br ready`
   and ask which one.
4. `git fetch origin`, then
   `git worktree add .claude/worktrees/<id> -b <id> origin/<trunk>`
   (branch already exists? drop `-b`; you're resuming).
5. `br update <id> --claim`.
6. `cd` into the worktree. Every edit happens there. Say the path out loud.

## During

- Commit early, commit often, on the branch. `wip:` prefixes are fine — there
  is no code review to keep tidy for. Never end a turn claiming "done" with a
  dirty tree.
- `br` from inside the worktree finds the trunk's `.beads/` by walking up;
  when in doubt run it from `~/projects/<repo>`.

## `/work finish [<bead-id>]`

1. Commit everything; `git push -u origin <id>` (SSH prompt fails → retry).
2. Land it: `gh pr create --fill`, then `gh pr merge --squash --delete-branch`
   — **unless the repo has a process** (below), in which case leave the PR
   open and say so.
3. `br close <id> -r "<one line>"`.
4. `cd ~/projects/<repo>`, `git worktree remove .claude/worktrees/<id>`,
   `git pull --ff-only`.
5. Report: bead closed, PR URL, worktree gone. Three lines, not a saga.

### Repos with process (PR stays open for the human)

- anything that deploys to Salesforce **prod**
- `syncx-infra` (real GCP)
- `dotfiles` (signed commits — hand the commit to the user via `!`)
- any repo whose `CLAUDE.md` says so

## `/work status`

Across `~/projects/*/`: `git worktree list` (any line beyond the trunk is in
flight) and `br list -s in_progress`. In-flight work with no live session
gets **finished or folded** — commit its dirt onto its branch, remove the
worktree — never left to rot. There is no automatic sweeper; this is it.
