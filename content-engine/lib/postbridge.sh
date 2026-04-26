#!/bin/bash
# Post Bridge helper for OnTrack content pipeline.
# API reference: https://api.post-bridge.com/reference
# Exports: pb_accounts, pb_upload, pb_create_post, pb_build_payload, pb_get_post, pb_delete_post.
# Auth:  Authorization: Bearer $POST_BRIDGE_API_KEY

set -euo pipefail

PB_BASE="https://api.post-bridge.com"

_pb_require_key() {
  if [ -z "${POST_BRIDGE_API_KEY:-}" ]; then
    echo "ERROR: POST_BRIDGE_API_KEY is not set." >&2
    return 1
  fi
}

_pb_curl() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  local url="${PB_BASE}${path}"
  if [ -n "$data" ]; then
    curl -sS -X "$method" "$url" \
      -H "Authorization: Bearer ${POST_BRIDGE_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -sS -X "$method" "$url" \
      -H "Authorization: Bearer ${POST_BRIDGE_API_KEY}"
  fi
}

# pb_accounts — GET /v1/social-accounts
pb_accounts() {
  _pb_require_key || return 1
  _pb_curl GET /v1/social-accounts
}

# pb_upload <file_path>  →  {"media_id":"..."} on success
pb_upload() {
  _pb_require_key || return 1
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi
  local ext size name mime lower_ext
  ext="${file##*.}"
  lower_ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  size=$(wc -c < "$file" | tr -d ' ')
  name=$(basename "$file")
  case "$lower_ext" in
    mp4)      mime="video/mp4" ;;
    mov)      mime="video/quicktime" ;;
    webm)     mime="video/webm" ;;
    jpg|jpeg) mime="image/jpeg" ;;
    png)      mime="image/png" ;;
    gif)      mime="image/gif" ;;
    *)        mime="application/octet-stream" ;;
  esac

  # Step 1: request a signed upload URL + media id
  local create_body create_resp
  create_body=$(printf '{"mime_type":"%s","size_bytes":%d,"name":"%s"}' "$mime" "$size" "$name")
  create_resp=$(_pb_curl POST /v1/media/create-upload-url "$create_body")

  local upload_url media_id
  upload_url=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('upload_url',''))" "$create_resp")
  media_id=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('media_id',''))" "$create_resp")

  if [ -z "$upload_url" ] || [ -z "$media_id" ]; then
    echo "ERROR: create-upload-url failed: $create_resp" >&2
    return 1
  fi

  # Step 2: PUT file bytes to the signed URL
  local http_status
  http_status=$(curl -sS -o /tmp/pb-upload.out -w "%{http_code}" \
    -X PUT "$upload_url" \
    -H "Content-Type: ${mime}" \
    --data-binary "@${file}")

  if [ "$http_status" != "200" ] && [ "$http_status" != "204" ]; then
    echo "ERROR: media PUT returned HTTP $http_status" >&2
    cat /tmp/pb-upload.out >&2 || true
    return 1
  fi

  echo "{\"media_id\":\"${media_id}\"}"
}

# pb_create_post <payload_json>  →  passes JSON to POST /v1/posts
pb_create_post() {
  _pb_require_key || return 1
  local payload="$1"
  _pb_curl POST /v1/posts "$payload"
}

# pb_build_payload <default_caption> <media_id> <accounts_csv> [platform_configs_json]
pb_build_payload() {
  local caption="$1"
  local media_id="$2"
  local accounts_csv="$3"
  local platform_configs="${4:-{}}"

  python3 <<PY
import json
caption = """$caption"""
media_id = "$media_id"
accounts = [int(x) for x in """$accounts_csv""".split(",") if x.strip()]
try:
    pc = json.loads('''$platform_configs''')
except Exception:
    pc = {}
body = {
  "caption": caption,
  "social_accounts": accounts,
  "media": [media_id] if media_id else [],
  "platform_configurations": pc,
}
print(json.dumps(body))
PY
}

# pb_get_post <id>
pb_get_post() {
  _pb_require_key || return 1
  _pb_curl GET "/v1/posts/$1"
}

# pb_delete_post <id>
pb_delete_post() {
  _pb_require_key || return 1
  _pb_curl DELETE "/v1/posts/$1"
}

# CLI dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    accounts) pb_accounts ;;
    upload)   pb_upload "$@" ;;
    post)     pb_create_post "$@" ;;
    build)    pb_build_payload "$@" ;;
    get)      pb_get_post "$@" ;;
    delete)   pb_delete_post "$@" ;;
    *) echo "usage: $0 {accounts|upload <file>|post <json>|build <caption> <media_id> <accounts_csv> [platform_configs_json]|get <id>|delete <id>}" >&2; exit 2 ;;
  esac
fi
