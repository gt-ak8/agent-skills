#!/usr/bin/env bash
# fleet-reg.sh          print the fleet register path for the current project
# fleet-reg.sh --dir    print its directory only
#
# The register used to default to ./fleet.tsv, which put it wherever the
# orchestrator happened to stand: littering the repo as an untracked file, and
# - worse - making the path depend on cwd. An orchestrator that spawned from the
# repo root and later ran advise.sh from a worktree read a register that did not
# exist, and advise.sh silently fell back to guessing the newest session, which
# is exactly the guess the pinned session ids were added to avoid.
#
# So the path is keyed to the PROJECT, not to cwd:
#   $FLEET_HOME/<project>/fleet.tsv        (default ~/.agents/fleets)
#
# <project> is the basename of the repo's MAIN worktree - via --git-common-dir,
# whose parent is the main worktree root even when called from a linked
# worktree. Every worktree of one repo therefore shares one register, which is
# what a fleet spanning several worktrees needs. Outside a git repo it falls
# back to the basename of $PWD.
#
# Two escape hatches, both honoured by the callers:
#   REG=/some/file.tsv   exact register file, bypasses all of this
#   FLEET_HOME=/some/dir relocate the tree of registers
#
# Caveat: two different repos with the same directory name collide in one
# register. Names must be unique among live agents anyway, but if you run
# fleets in two same-named checkouts at once, set REG or FLEET_HOME.
set -uo pipefail

FLEET_HOME="${FLEET_HOME:-$HOME/.agents/fleets}"

project_slug() {
  local common root
  if common=$(git rev-parse --git-common-dir 2>/dev/null) && [ -n "$common" ]; then
    common=$(cd "$common" 2>/dev/null && pwd) || common=""
    if [ -n "$common" ]; then
      case "$common" in
        */.git) root=${common%/.git} ;;   # normal worktree
        *) root=$common ;;                # bare or unusual layout
      esac
      printf '%s' "$(basename "$root")" | tr -c 'A-Za-z0-9._-' '-'
      return
    fi
  fi
  printf '%s' "$(basename "$PWD")" | tr -c 'A-Za-z0-9._-' '-'
}

DIR="$FLEET_HOME/$(project_slug)"
[ "${1:-}" = --dir ] && { printf '%s\n' "$DIR"; exit 0; }
mkdir -p "$DIR" 2>/dev/null || { echo "fleet-reg: cannot create $DIR" >&2; exit 1; }
printf '%s/fleet.tsv\n' "$DIR"
