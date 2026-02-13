#!/bin/bash

# Hook-based activity detection for Skwad
# Called by UserPromptSubmit (running) and Stop (idle) hooks
# Usage: activity.sh running|idle

source "$(dirname "$0")/log.sh"

status="$1"
input=$(cat)

skwad_log "Activity" "status=$status agent_id=$SKWAD_AGENT_ID"
skwad_log "Activity" "payload=$input"

if [ -z "$status" ] || [ -z "$SKWAD_AGENT_ID" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Fire and forget — don't block the agent
curl -s -o /dev/null -X POST \
  -H "Content-Type: application/json" \
  -d "{\"agent_id\":\"${SKWAD_AGENT_ID}\",\"status\":\"${status}\"}" \
  "${SKWAD_URL}/api/v1/agent/status" 2>/dev/null &

exit 0
