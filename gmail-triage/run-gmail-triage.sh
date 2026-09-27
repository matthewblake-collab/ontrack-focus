#!/bin/bash
# OnTrack — Gmail Triage (headless). Fired by launchd at 6am local.
# Mirrors content-engine/run-morning-routine.sh.
#
# Delivery: NONE. 2026-08-03 schedule compaction — this job notifies nobody. The skill writes
# out/summary-<YYYYMMDD>.txt and the daily newsletter reads it. The Telegram cred block below is
# commented out, not deleted, because lib/telegram.sh still exists and re-enabling is two lines.
# ~/.zshrc is NOT sourced — see the note below.
# Root is /bin/bash, NOT zsh: macOS TCC attributes Full Disk Access to the LaunchAgent ROOT program,
# and this script lives under the TCC-protected ~/Desktop (zsh root = 126, proven 2026-07-25).
# The /gmail-triage skill loads the triage logic — this wrapper just invokes Claude.

set -euo pipefail

# DELETED 2026-07-25: `[ -f ~/.zshrc ] && source ~/.zshrc 2>/dev/null || true`.
# ~/.zshrc sources ~/.bun/_bun, which is zsh-only (line 958 uses the `(N)` glob qualifier). Under a
# /bin/bash root that is a PARSE-time error, which aborts the whole script with status 2 — `|| true`
# does not catch a parse abort, and the `2>/dev/null` hid the reason. It killed the first live run.
# Verified lossless before deleting: nothing in this script, lib/, or the skill references any var
# that line uniquely supplied (BUN_INSTALL / SUPABASE_* / OBSIDIAN_API_KEY / ELEVENLABS_API_KEY /
# POST_BRIDGE_API_KEY / SLACK_APP_TOKEN). The chain needs only HOME, TELEGRAM_BOT_TOKEN and
# TELEGRAM_MATT_CHAT_ID; claude authenticates from its own store, not the environment.
# Fail-closed creds. The plist supplies TELEGRAM_MATT_CHAT_ID (not a secret); the TOKEN is read from
# the Keychain at runtime and is NEVER stored in the plist, this script, or any commit
# (escalate.mjs pattern). Warnings are loud so a missing cred can't fail silently.
# DISABLED 2026-08-03 (schedule compaction): no delivery step remains, so the token had no
# consumer and was being exported into the claude child environment for nothing. Uncomment this
# block AND restore step 4's telegram.sh call in the skill to put notification back — one without
# the other is a no-op.
# if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
#   TELEGRAM_BOT_TOKEN="$(security find-generic-password -s telegram-bot-token -w || true)"
#   export TELEGRAM_BOT_TOKEN
# fi
# [ -n "${TELEGRAM_BOT_TOKEN:-}" ]    || echo "WARN: TELEGRAM_BOT_TOKEN unresolved — triage runs, summary delivery will fail" >&2
# [ -n "${TELEGRAM_MATT_CHAT_ID:-}" ] || echo "WARN: TELEGRAM_MATT_CHAT_ID unresolved — summary delivery will fail" >&2

cd "$HOME/Desktop/OnTrack/OnTrack/gmail-triage"

LOG="/tmp/gmail-triage-$(date +%Y%m%d).log"

# Least privilege: Gmail read + label/unlabel + create_label + create_draft only.
# NO send, NO trash/delete tools.
/Users/matthewblake/.local/bin/claude --print "/gmail-triage" \
  --allowedTools "Bash,Read,Write,mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread,mcp__claude_ai_Gmail__list_labels,mcp__claude_ai_Gmail__create_label,mcp__claude_ai_Gmail__label_thread,mcp__claude_ai_Gmail__unlabel_thread,mcp__claude_ai_Gmail__create_draft" \
  2>&1 | tee "$LOG"
