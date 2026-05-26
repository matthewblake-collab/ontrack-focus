#!/bin/bash
# OnTrack — Gmail Triage (headless). Fired by launchd at 6am local.
# Mirrors content-engine/run-morning-routine.sh.
#
# Delivery: Telegram (Jarvis bot) via lib/telegram.sh.
# Creds: TELEGRAM_BOT_TOKEN + TELEGRAM_MATT_CHAT_ID exported in ~/.zshrc.
# The /gmail-triage skill loads the triage logic — this wrapper just invokes Claude.

set -euo pipefail

# launchd runs without a login shell — make ~/.zshrc-exported env available.
# shellcheck disable=SC1090
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

cd "$HOME/Desktop/OnTrack/OnTrack/gmail-triage"

LOG="/tmp/gmail-triage-$(date +%Y%m%d).log"

# Least privilege: Gmail read + label/unlabel + create_label + create_draft only.
# NO send, NO trash/delete tools.
/Users/matthewblake/.local/bin/claude --print "/gmail-triage" \
  --allowedTools "Bash,Read,Write,mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread,mcp__claude_ai_Gmail__list_labels,mcp__claude_ai_Gmail__create_label,mcp__claude_ai_Gmail__label_thread,mcp__claude_ai_Gmail__unlabel_thread,mcp__claude_ai_Gmail__create_draft" \
  2>&1 | tee "$LOG"
