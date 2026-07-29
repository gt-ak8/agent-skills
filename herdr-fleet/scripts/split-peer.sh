#!/usr/bin/env bash
# split-peer.sh <existing-agent> <peer-name> <brief-file> [effort] [model]
# Starts a second agent in a split pane of an existing agent's tab, on the SAME
# working directory. This is the reviewer pattern: the peer sees the exact tree
# the first agent produced, costs no extra worktree, and dies with the same tab.
# The existing agent must still be alive.
set -euo pipefail
SRC="${1:?existing agent}"; NAME="${2:?peer name}"; BRIEF="${3:?brief file}"
EFFORT="${4:-high}"; MODEL="${5:-claude-sonnet-4-6}"
HERE="$(cd "$(dirname "$0")" && pwd)"

INFO=$(herdr agent get "$SRC")
SPANE=$(printf '%s' "$INFO" | jq -r '.result.agent.pane_id')
CWD=$(printf '%s' "$INFO" | jq -r '.result.agent.cwd')
[ "$SPANE" != "null" ] || { echo "no live agent named $SRC" >&2; exit 1; }

PJSON=$(herdr pane split --pane "$SPANE" --direction right --cwd "$CWD" --no-focus)
PANE=$(printf '%s' "$PJSON" | jq -r '.result.pane.pane_id')

SID=$(uuidgen | tr 'A-Z' 'a-z')

"$HERE/agent-start.sh" "$NAME" "$PANE" "$EFFORT" "$MODEL" "$SID"

"$HERE/send.sh" "$NAME" "$BRIEF"
printf '%s\t%s\t%s\t%s\t%s\n' "$NAME" "$PANE" "-" "$CWD" "$SID" \
  | tee -a "${REG:-$("$HERE/fleet-reg.sh")}"
