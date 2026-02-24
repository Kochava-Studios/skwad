#!/bin/bash

# Codex notify hook for Skwad
# Called by Codex with a single JSON argument ($1) on agent-turn-complete
# Usage: notify.sh '<json-payload>'

source "$(dirname "$0")/log.sh"

json="$1"
event_type=$(echo "$json" | jq -r '.type')

skwad_log "Notify" "event_type=$event_type agent_id=$SKWAD_AGENT_ID"
skwad_log "Notify" "payload=$json"

if [ -z "$SKWAD_AGENT_ID" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

case "$event_type" in
  agent-turn-complete)
    # agent-turn-complete = agent finished its turn, now idle
    curl -s -o /dev/null -X POST \
      -H "Content-Type: application/json" \
      -d "{\"agent_id\":\"${SKWAD_AGENT_ID}\",\"agent\":\"codex\",\"hook\":\"notify\",\"status\":\"idle\",\"payload\":${json}}" \
      "${SKWAD_URL}/api/v1/agent/status" 2>/dev/null &
    ;;
esac

exit 0
