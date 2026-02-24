#!/bin/bash
# Shared hook debug logger
# Set SKWAD_DEBUG=1 to enable. Logs to /tmp/skwad-hooks/<agent_id>.log
# Clean up: rm -rf /tmp/skwad-hooks

skwad_log() {
  # [ "$SKWAD_DEBUG" != "1" ] && return
  local hook_name="$1"
  shift
  local log_dir="/tmp/skwad-hooks"
  local agent="${SKWAD_AGENT_ID:-unknown}"
  mkdir -p "$log_dir"
  echo "[$(date '+%H:%M:%S')] $hook_name: $*" >> "$log_dir/$agent.log"
}
