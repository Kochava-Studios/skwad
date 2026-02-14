#!/bin/bash

source "$(dirname "$0")/log.sh"

input=$(cat)
source_type=$(echo "$input" | jq -r '.source')
session_id=$(echo "$input" | jq -r '.session_id')
cwd=$(pwd)

skwad_log "SessionStart" "agent_id=$SKWAD_AGENT_ID session_id=$session_id source=$source_type cwd=$cwd"
skwad_log "SessionStart" "payload=$input"

# Only process the startup event, not resume
if [ "$source_type" != "startup" ]; then
  exit 0
fi

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Need agent ID to register
if [ -z "$SKWAD_AGENT_ID" ]; then
  exit 0
fi

# Check if Skwad MCP server is running
health=$(curl -s -o /dev/null -w "%{http_code}" "$SKWAD_URL/health" 2>/dev/null)

if [ "$health" = "200" ]; then

  # Register agent — forward raw hook payload for server-side metadata extraction
  register_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"agent_id\":\"${SKWAD_AGENT_ID}\",\"session_id\":\"${session_id}\",\"payload\":${input:-\{\}}}" \
    "${SKWAD_URL}/api/v1/agent/register" 2>/dev/null)

  skwad_log "SessionStart" "register_response=$register_response"

  # Build context from register response (skwad members)
  members=$(echo "$register_response" | jq -r '.skwadMembers // [] | map("\(.name) (\(.id)) - \(.folder) [\(.status)]") | join(", ")' 2>/dev/null)

  context="Skwad agent manager detected at $SKWAD_URL. You are registered with the skwad. Your agent ID is: ${SKWAD_AGENT_ID}."
  if [ -n "$members" ] && [ "$members" != "" ]; then
    context="$context Your skwad members: $members."
  fi

  # Escape for JSON
  context=$(echo "$context" | sed 's/"/\\"/g')

  echo "{ \"hookSpecificOutput\": { \"hookEventName\": \"SessionStart\", \"additionalContext\": \"$context\" } }"
else
  echo "{ \"hookSpecificOutput\": { \"hookEventName\": \"SessionStart\", \"additionalContext\": \"Register in the skwad using your agent ID and session ID.\" } }"
fi

exit 0
