#!/bin/bash

# Generic hook event logger for Skwad
# Forwards hook events to the Skwad server
# Usage: hook-event.sh <hook_type>

source "$(dirname "$0")/log.sh"

hook_type="$1"
input=$(cat)

skwad_log "HookEvent" "type=$hook_type agent_id=$SKWAD_AGENT_ID"
skwad_log "HookEvent" "payload=$input"

if [ -z "$hook_type" ] || [ -z "$SKWAD_AGENT_ID" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Fire and forget — don't block the agent
curl -s -o /dev/null -X POST \
  -H "Content-Type: application/json" \
  -d "{\"agent_id\":\"${SKWAD_AGENT_ID}\",\"hook_type\":\"${hook_type}\",\"payload\":${input}}" \
  "${SKWAD_URL}/api/v1/agent/hook-event" 2>/dev/null &

exit 0
