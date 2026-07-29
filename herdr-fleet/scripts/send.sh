#!/usr/bin/env bash
# send.sh <agent-name> <prompt-file>
# Sends a prompt file to a live agent and VERIFIES it was submitted.
# A prompt can land in the composer without being sent; never assume.
set -uo pipefail
N="${1:?agent name}"; F="${2:?prompt file}"
[ -f "$F" ] || { echo "no such prompt file: $F" >&2; exit 2; }

st() { herdr agent get "$N" 2>/dev/null | jq -r '.result.agent.agent_status'; }

herdr agent prompt "$N" "$(cat "$F")" >/dev/null 2>&1
for i in 1 2 3; do
  sleep 4
  [ "$(st)" = "working" ] && { echo "$N submitted (attempt $i)"; exit 0; }
  herdr agent send-keys "$N" enter >/dev/null 2>&1
done
sleep 5
[ "$(st)" = "working" ] && { echo "$N submitted (via enter)"; exit 0; }
echo "$N NOT SUBMITTED (status=$(st))" >&2; exit 1
