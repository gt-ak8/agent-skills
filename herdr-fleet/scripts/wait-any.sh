#!/usr/bin/env bash
# wait-any.sh "<pane-or-name-regex>" [max-seconds] [interval]
# Returns as soon as ANY matching agent leaves 'working'. Poll the fleet, never
# one session at a time: the first to settle is the one that needs you.
# Run it in the background and let the harness notify you.
set -uo pipefail
RE="${1:?regex}"; MAX="${2:-1800}"; IV="${3:-30}"; T=0
while [ "$T" -lt "$MAX" ]; do
  OUT=$(herdr agent list 2>/dev/null | jq -r --arg re "$RE" \
    '.result.agents[]?|select((.pane_id|test($re)) or ((.name//"")|test($re)))|"\(.name//.pane_id) \(.agent_status)"')
  [ -z "$OUT" ] && { echo "no matching agents"; exit 0; }
  SETTLED=$(printf '%s\n' "$OUT" | grep -v ' working$' || true)
  if [ -n "$SETTLED" ]; then printf '%s\n' "$SETTLED"; exit 0; fi
  sleep "$IV"; T=$((T+IV))
done
echo "timeout after ${MAX}s"; printf '%s\n' "$OUT"
