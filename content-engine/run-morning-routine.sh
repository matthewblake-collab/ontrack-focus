#!/bin/bash
# OnTrack Content Engine — Morning Routine (schedule trigger)
# Fired by system cron Mon/Wed/Fri 7:30am AEST.
# Also registered as a durable CC Routine (CronCreate) for when Claude is running interactively.
#
# Delivery channel: Slack #content-approval (replaces Telegram).
# Credentials: ~/.slack-bot-config.json + $ELEVENLABS_API_KEY.
# The /morning-content-routine skill loads these itself — this wrapper just invokes Claude.

set -euo pipefail

# Ensure env vars that ~/.zshrc exports are available in cron (which runs without a login shell).
# shellcheck disable=SC1090
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

cd "$HOME/Desktop/OnTrack/OnTrack/content-engine"

LOG="/tmp/morning-routine-$(date +%Y%m%d).log"

/Users/matthewblake/.local/bin/claude --print "/morning-content-routine" \
  --allowedTools "WebSearch,WebFetch,Bash,Read,Write,Edit,mcp__claude_ai_Supabase__execute_sql,mcp__claude_ai_Supabase__apply_migration" \
  2>&1 | tee "$LOG"
