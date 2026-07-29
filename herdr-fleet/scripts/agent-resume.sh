#!/usr/bin/env bash
# agent-resume.sh <new-name> <pane> <continue-brief-file> [effort] [model]
# Restarts claude in an EXISTING pane with --continue, so the agent picks up the
# session that was already running in that pane's cwd, then submits a short
# continuation brief.
#
# Why this exists: when the 5-hour quota runs out, claude raises a modal
# ("Stop and wait for limit to reset / Ask your admin"). Escape does not dismiss
# it - it exits the process. So every pane in the fleet becomes a bare shell at
# the same moment, and `herdr agent prompt` on it returns agent_prompt_stalled.
# The work is not lost: --continue re-reads the on-disk session for that cwd,
# and re-reads credentials, which a surviving process would not have done.
#
# The agent name must be new; the old record still holds the previous one.
set -uo pipefail
NAME="${1:?new agent name}"; PANE="${2:?pane}"; BRIEF="${3:?continue brief file}"
EFFORT="${4:-high}"; MODEL="${5:-claude-sonnet-4-6}"

[ -f "$BRIEF" ] || { echo "no such brief: $BRIEF" >&2; exit 1; }

case "$MODEL:$EFFORT" in
  *4-6:xhigh) echo "$NAME: $MODEL has no xhigh effort, using high" >&2; EFFORT=high ;;
esac

for i in 1 2 3 4 5 6; do
  if OUT=$(herdr agent start "$NAME" --kind claude --pane "$PANE" --timeout 180000 \
             -- --model "$MODEL" --effort "$EFFORT" --continue 2>&1); then
    STARTED=1; break
  fi
  case "$OUT" in
    *agent_pane_busy*) sleep $((i * 2)) ;;
    *) printf '%s\n' "$OUT" >&2; exit 1 ;;
  esac
done
[ "${STARTED:-}" = 1 ] || { echo "$NAME: pane never became an available shell" >&2; exit 1; }

# The composer is not ready the instant the process starts, and `prompt` appends
# to whatever is already there, so a stalled first attempt must not be retried
# blindly - re-read the pane instead of sending the text twice.
for i in 1 2 3 4 5 6 7 8; do
  sleep $((i + 1))
  if herdr agent prompt "$NAME" "$(cat "$BRIEF")" >/dev/null 2>&1; then
    echo "$NAME resumed on $PANE (attempt $i)"
    exit 0
  fi
done
echo "$NAME: started on $PANE but the continuation brief never submitted" >&2
exit 1
