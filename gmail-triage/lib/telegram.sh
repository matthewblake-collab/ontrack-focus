#!/bin/bash
# Telegram delivery helper for the Gmail triage cron (Jarvis bot).
# Mirrors content-engine/lib/slack.sh shape. Reads TELEGRAM_BOT_TOKEN +
# TELEGRAM_MATT_CHAT_ID from env (exported in ~/.zshrc, sourced by the wrapper).
# PLAIN TEXT ONLY — no parse_mode (email subjects/snippets break Telegram Markdown).

set -euo pipefail

# telegram_send <text>
telegram_send() {
  local text="$1"
  : "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
  : "${TELEGRAM_MATT_CHAT_ID:?TELEGRAM_MATT_CHAT_ID not set}"
  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_MATT_CHAT_ID}" \
    --data-urlencode "text=${text}"
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    send) shift; telegram_send "$@" ;;
    *) echo "usage: $0 send <text>" >&2; exit 2 ;;
  esac
fi
