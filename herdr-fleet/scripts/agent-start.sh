#!/usr/bin/env bash
# agent-start.sh <name> <pane> [effort] [model] [session-id]
# herdr agent start, retried. A freshly created pane is not an available shell
# for a beat or two - its shell is still initializing - and `agent start` fails
# hard with agent_pane_busy rather than waiting. Every launch path goes through
# this so the race is handled once.
#
# session-id: pass a UUID to pin the agent's session file. Herdr reports a pane
# id and a cwd but never a session id, and a pane that shells out to `claude -p`
# writes newer session files in the same cwd - so "the newest .jsonl for this
# cwd" is not the agent's session. Pinning the id at launch is what makes
# advise.sh able to fork exactly the right conversation later.
set -uo pipefail
NAME="${1:?name}"; PANE="${2:?pane}"; EFFORT="${3:-high}"; MODEL="${4:-claude-sonnet-4-6}"
SID="${5:-}"

# claude-sonnet-5 is excluded from this fleet by standing decision. Refuse rather
# than substitute: a silent downgrade would hide which model actually ran.
case "$MODEL" in
  claude-sonnet-5*)
    echo "$NAME: claude-sonnet-5 is excluded from this fleet - use claude-sonnet-4-6" >&2
    exit 1 ;;
esac

# A bare alias resolves to the LATEST model in its family, so `sonnet` lands on
# the one model that is excluded, and `opus` silently moves the day a new Opus
# ships. Only full ids are accepted.
case "$MODEL" in
  claude-*) ;;
  *) echo "$NAME: '$MODEL' is an alias, not a model id - aliases drift to the newest model. Pass the full id" >&2
     exit 1 ;;
esac

# Efforts are uniform across models - low, medium, high, xhigh, max - and an
# unrecognised one does not fail the launch: the CLI warns and silently uses the
# default effort instead. That silence is the hazard, so reject a typo here
# rather than discovering a whole wave ran at the default.
case "$EFFORT" in
  low|medium|high|xhigh|max) ;;
  *) echo "$NAME: '$EFFORT' is not an effort level (low|medium|high|xhigh|max). The CLI would warn and silently use the default" >&2
     exit 1 ;;
esac

SIDARG=()
if [ -n "$SID" ]; then
  case "$SID" in
    [0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*) SIDARG=(--session-id "$SID") ;;
    *) echo "$NAME: '$SID' is not a UUID" >&2; exit 1 ;;
  esac
fi

for i in 1 2 3 4 5 6; do
  if OUT=$(herdr agent start "$NAME" --kind claude --pane "$PANE" --timeout 180000 \
             -- --model "$MODEL" --effort "$EFFORT" "${SIDARG[@]}" 2>&1); then
    exit 0
  fi
  case "$OUT" in
    *agent_pane_busy*) sleep $((i * 2)) ;;
    *) printf '%s\n' "$OUT" >&2; exit 1 ;;
  esac
done
echo "agent start $NAME on $PANE: pane never became an available shell" >&2
exit 1
