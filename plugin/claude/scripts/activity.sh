#!/bin/bash

# Hook-based activity detection for Skwad
# Called by Claude hooks to report agent status changes
# Usage: activity.sh <HookName> <running|idle|input>

source "$(dirname "$0")/log.sh"

hook="$1"
status="$2"
input=$(cat)

skwad_log "Activity" "hook=$hook status=$status agent_id=$SKWAD_AGENT_ID"
skwad_log "Activity" "payload=$input"

if [ -z "$hook" ] || [ -z "$status" ] || [ -z "$SKWAD_AGENT_ID" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Fire and forget — don't block the agent
# Forward raw hook payload for server-side metadata extraction
curl -s -o /dev/null -X POST \
  -H "Content-Type: application/json" \
  -d "{\"agent_id\":\"${SKWAD_AGENT_ID}\",\"agent\":\"claude\",\"hook\":\"${hook}\",\"status\":\"${status}\",\"payload\":${input:-\{\}}}" \
  "${SKWAD_URL}/api/v1/agent/status" 2>/dev/null &

exit 0
