#!/bin/bash

# Hook-based activity detection for Skwad
# Called by UserPromptSubmit (running) and Stop (idle) hooks
# Usage: activity.sh running|idle

status="$1"
if [ -z "$status" ]; then
  exit 0
fi

# Read session_id from stdin (hook input JSON)
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')

if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Fire and forget — don't block the agent
curl -s -o /dev/null -X POST "${SKWAD_URL}/api/v1/agent/status?session_id=${session_id}&status=${status}" 2>/dev/null &

exit 0
