#!/bin/bash

# Generic hook event logger for Skwad
# Forwards hook events to the Skwad server for logging
# Usage: hook-event.sh <hook_type>

hook_type="$1"
if [ -z "$hook_type" ]; then
  exit 0
fi

# Read hook input from stdin
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')

if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Fire and forget — don't block the agent
curl -s -o /dev/null -X POST \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"${session_id}\",\"hook_type\":\"${hook_type}\",\"payload\":${input}}" \
  "${SKWAD_URL}/api/v1/agent/hook-event" 2>/dev/null &

exit 0
