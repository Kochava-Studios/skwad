#!/bin/bash

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
cwd=$(pwd)

SKWAD_URL="${SKWAD_URL:-http://127.0.0.1:8766}"

# Check if Skwad MCP server is running
health=$(curl -s -o /dev/null -w "%{http_code}" "$SKWAD_URL/health" 2>/dev/null)

if [ "$health" = "200" ]; then
  echo -n "{ \"hookSpecificOutput\": { \"hookEventName\": \"SessionStart\", \"additionalContext\": \""
  echo -n "Skwad agent manager detected at $SKWAD_URL. "
  echo -n "Your session ID is: ${session_id}. When registering with skwad, pass this as your sessionId. "
  echo -n "Use /skwad:list-agents, /skwad:send, /skwad:check, /skwad:broadcast to communicate with other agents. "
  echo -n "Use /skwad:create-agent, /skwad:list-repos, /skwad:list-worktrees to manage agents and repos. "
  echo -n "Use /skwad:show-markdown to display markdown in Skwad's preview panel."
  echo "\" } }"
else
  echo -n "{ \"hookSpecificOutput\": { \"hookEventName\": \"SessionStart\", \"additionalContext\": \""
  echo -n "Skwad agent manager not detected. Skwad commands will not be available."
  echo "\" } }"
fi

exit 0
