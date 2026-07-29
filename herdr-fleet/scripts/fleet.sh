#!/usr/bin/env bash
# fleet.sh [regex]        one line per live agent: name, status, cwd
# fleet.sh --stuck        agents that settled and are waiting on you
# fleet.sh --close <name> close ONE agent's pane; closes the tab only if it is
#                        the last pane. A peer started with split-peer.sh shares
#                        the tab, and closing the tab would kill it too.
set -uo pipefail

list() {
  herdr agent list 2>/dev/null | jq -r --arg re "${1:-.}" \
    '.result.agents[]?|select(((.name//"")|test($re)) or (.pane_id|test($re)))
     |[(.name//"-"), .agent_status, .pane_id, .cwd]|@tsv'
}

case "${1:-}" in
  --stuck) list . | awk -F'\t' '$2!="working"' ;;
  --close)
    N="${2:?agent name}"
    INFO=$(herdr agent get "$N")
    TAB=$(printf '%s' "$INFO" | jq -r '.result.agent.tab_id')
    PANE=$(printf '%s' "$INFO" | jq -r '.result.agent.pane_id')
    [ "$TAB" = "null" ] && { echo "no live agent $N" >&2; exit 1; }
    PEERS=$(herdr pane list --workspace "${HERDR_WORKSPACE_ID:?}" \
      | jq -r --arg t "$TAB" '[.result.panes[]?|select(.tab_id==$t)]|length')
    herdr pane close "$PANE" >/dev/null || exit 1
    if [ "${PEERS:-1}" -le 1 ]; then
      herdr tab close "$TAB" >/dev/null 2>&1
      echo "closed $N ($PANE, tab $TAB - was the last pane)"
    else
      echo "closed $N ($PANE; tab $TAB kept, $((PEERS-1)) peer pane(s) still live)"
    fi ;;
  *) list "${1:-.}" | column -t -s$'\t' ;;
esac
