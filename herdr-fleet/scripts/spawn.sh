#!/usr/bin/env bash
# spawn.sh <name> <cwd> <brief-file> [effort] [model]
# One tab, one agent, one brief. The tab label IS the index from a pane back to
# the work, so name it <role>-<id>-<slug> and never reuse a name.
# Appends "name<TAB>pane<TAB>tab<TAB>cwd<TAB>session-id" to $REG, which defaults
# to the project's register under ~/.agents/fleets - see fleet-reg.sh. The
# session id is generated here rather than read back later, because nothing in
# Herdr reports one - see agent-start.sh.
set -euo pipefail
NAME="${1:?name}"; CWD="${2:?cwd}"; BRIEF="${3:?brief file}"
EFFORT="${4:-high}"; MODEL="${5:-claude-sonnet-4-6}"
WS="${HERDR_WORKSPACE_ID:?not inside a Herdr pane}"
HERE="$(cd "$(dirname "$0")" && pwd)"
REG="${REG:-$("$HERE/fleet-reg.sh")}"

[ -d "$CWD" ] || { echo "no such cwd: $CWD" >&2; exit 1; }
[ -f "$BRIEF" ] || { echo "no such brief: $BRIEF" >&2; exit 1; }

TABJSON=$(herdr tab create --workspace "$WS" --label "$NAME" --cwd "$CWD" --no-focus)
PANE=$(printf '%s' "$TABJSON" | jq -r '.result.root_pane.pane_id')
TAB=$(printf '%s' "$TABJSON" | jq -r '.result.tab.tab_id')

SID=$(uuidgen | tr 'A-Z' 'a-z')

"$HERE/agent-start.sh" "$NAME" "$PANE" "$EFFORT" "$MODEL" "$SID"

"$HERE/send.sh" "$NAME" "$BRIEF"
printf '%s\t%s\t%s\t%s\t%s\n' "$NAME" "$PANE" "$TAB" "$CWD" "$SID" | tee -a "$REG"
