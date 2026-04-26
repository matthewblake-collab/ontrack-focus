#!/bin/bash
# Slack helper for OnTrack content approval pipeline.
# Reads ~/.slack-bot-config.json for bot_token + channel IDs.
# Provides: slack_post_message, slack_upload_file, slack_poll_reply.

set -euo pipefail

SLACK_CFG="$HOME/.slack-bot-config.json"

_slack_read_cfg() {
  if [ ! -f "$SLACK_CFG" ]; then
    echo "ERROR: $SLACK_CFG not found." >&2
    return 1
  fi
  python3 -c "import json,sys; d=json.load(open('$SLACK_CFG')); print(d['$1'] if '$1' in d else d.get('channels',{}).get('$1',''))"
}

_slack_token() { _slack_read_cfg bot_token; }

# slack_resolve_channel <name>  →  channel id (name = approval|posted|alerts|briefs, or raw Cxxxx)
slack_resolve_channel() {
  local name="$1"
  case "$name" in
    C*) echo "$name" ;;
    *)  _slack_read_cfg "$name" ;;
  esac
}

# slack_post_message <channel> <text> [thread_ts]
slack_post_message() {
  local channel text thread_ts token
  channel=$(slack_resolve_channel "$1")
  text="$2"
  thread_ts="${3:-}"
  token=$(_slack_token)

  local payload
  payload=$(python3 -c "
import json, sys
d = {'channel': sys.argv[1], 'text': sys.argv[2]}
if sys.argv[3]:
    d['thread_ts'] = sys.argv[3]
print(json.dumps(d))
" "$channel" "$text" "$thread_ts")

  curl -sS -X POST "https://slack.com/api/chat.postMessage" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data "$payload"
}

# slack_upload_file <channel> <file_path> [initial_comment]
# Uses files.getUploadURLExternal → PUT file → files.completeUploadExternal (v2 flow).
slack_upload_file() {
  local channel file_path comment token filename filesize
  channel=$(slack_resolve_channel "$1")
  file_path="$2"
  comment="${3:-}"
  token=$(_slack_token)

  if [ ! -f "$file_path" ]; then
    echo "ERROR: file not found: $file_path" >&2
    return 1
  fi
  filename=$(basename "$file_path")
  filesize=$(wc -c < "$file_path" | tr -d ' ')

  # Step 1: get upload URL
  local step1
  step1=$(curl -sS -G "https://slack.com/api/files.getUploadURLExternal" \
    -H "Authorization: Bearer ${token}" \
    --data-urlencode "filename=${filename}" \
    --data-urlencode "length=${filesize}")

  local upload_url file_id
  upload_url=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('upload_url',''))" "$step1")
  file_id=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('file_id',''))" "$step1")

  if [ -z "$upload_url" ] || [ -z "$file_id" ]; then
    echo "ERROR: getUploadURLExternal failed: $step1" >&2
    return 1
  fi

  # Step 2: PUT the file bytes
  curl -sS -X POST "$upload_url" --data-binary "@${file_path}" >/dev/null

  # Step 3: complete the upload + share into channel
  local complete_payload
  complete_payload=$(python3 -c "
import json, sys
print(json.dumps({
  'files': [{'id': sys.argv[1], 'title': sys.argv[2]}],
  'channel_id': sys.argv[3],
  'initial_comment': sys.argv[4] or None
}))
" "$file_id" "$filename" "$channel" "$comment")

  curl -sS -X POST "https://slack.com/api/files.completeUploadExternal" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data "$complete_payload"
}

# slack_poll_reply <channel> <since_ts_seconds> [interval=30] [max_attempts=240]
# Prints first message text matching APPROVE|REJECT|CHANGE|SKIP, then exits 0.
# Exits 1 on timeout.
slack_poll_reply() {
  local channel since interval max_attempts token
  channel=$(slack_resolve_channel "$1")
  since="$2"
  interval="${3:-30}"
  max_attempts="${4:-240}"
  token=$(_slack_token)

  local i
  for i in $(seq 1 "$max_attempts"); do
    local resp
    resp=$(curl -sS -G "https://slack.com/api/conversations.history" \
      -H "Authorization: Bearer ${token}" \
      --data-urlencode "channel=${channel}" \
      --data-urlencode "oldest=${since}" \
      --data-urlencode "limit=20")

    local match
    match=$(python3 -c "
import json, sys, re
d = json.loads(sys.argv[1])
for m in d.get('messages', []):
    if m.get('subtype') == 'bot_message' or m.get('bot_id'):
        continue
    text = (m.get('text') or '').strip()
    if re.match(r'^(APPROVE|REJECT|CHANGE|SKIP)\b', text, re.I):
        print(text)
        break
" "$resp")

    if [ -n "$match" ]; then
      echo "$match"
      return 0
    fi
    sleep "$interval"
  done
  echo "ERROR: slack_poll_reply timed out after $((interval * max_attempts))s" >&2
  return 1
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    post)   slack_post_message "$@" ;;
    upload) slack_upload_file "$@" ;;
    poll)   slack_poll_reply "$@" ;;
    channel) slack_resolve_channel "$@" ;;
    *) echo "usage: $0 {post|upload|poll|channel} ..." >&2; exit 2 ;;
  esac
fi
