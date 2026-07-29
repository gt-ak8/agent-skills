#!/usr/bin/env bash
# respawn.sh <name> <old-pane> <cwd> <continue-brief> [effort] [model] [session-id]
# Kills a pane whose claude process is alive but unusable, opens a fresh tab on
# the same cwd, restarts claude with --continue, and submits a continuation
# brief. The session is on disk keyed by cwd, so --continue restores the context.
#
# Why a full respawn rather than prompting the live process: when the 5-hour
# quota runs out and the account is re-authenticated elsewhere, the running
# process keeps the credential it started with and answers every prompt with
# "Not logged in - please run /login". Credentials are only re-read at startup.
# The quota modal leaves a second failure mode in the same fleet - text pasted
# into the composer that never submits - and both clear on restart.
#
# The agent name must be new; the dead pane's record still holds the old one.
set -uo pipefail
NAME="${1:?new agent name}"; OLDPANE="${2:?old pane}"; CWD="${3:?cwd}"
BRIEF="${4:?continue brief}"; EFFORT="${5:-high}"; MODEL="${6:-claude-sonnet-4-6}"
SID="${7:-}"
WS="${HERDR_WORKSPACE_ID:?not inside a Herdr pane}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -d "$CWD" ] || { echo "no such cwd: $CWD" >&2; exit 1; }
[ -f "$BRIEF" ] || { echo "no such brief: $BRIEF" >&2; exit 1; }

herdr pane close "$OLDPANE" >/dev/null 2>&1 || echo "$NAME: could not close $OLDPANE, continuing" >&2

TABJSON=$(herdr tab create --workspace "$WS" --label "$NAME" --cwd "$CWD" --no-focus)
PANE=$(printf '%s' "$TABJSON" | jq -r '.result.root_pane.pane_id')

# --resume <id> when the session id is known, --continue otherwise. --continue
# picks the most recent session for the cwd, which is the wrong one if the pane
# ever shelled out to `claude -p`.
if [ -n "$SID" ]; then RES=(--resume "$SID"); else RES=(--continue); fi

for i in 1 2 3 4 5 6; do
  if OUT=$(herdr agent start "$NAME" --kind claude --pane "$PANE" --timeout 180000 \
             -- --model "$MODEL" --effort "$EFFORT" "${RES[@]}" 2>&1); then
    STARTED=1; break
  fi
  case "$OUT" in
    *agent_pane_busy*) sleep $((i * 2)) ;;
    *) printf '%s\n' "$OUT" >&2; exit 1 ;;
  esac
done
[ "${STARTED:-}" = 1 ] || { echo "$NAME: pane $PANE never became an available shell" >&2; exit 1; }

echo "$NAME started on $PANE (was $OLDPANE) - brief not yet sent"
