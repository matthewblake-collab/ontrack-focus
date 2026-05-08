#!/bin/bash
# ElevenLabs TTS helper for OnTrack content pipeline.
# Voice: Jordan — locked permanently (ID 4uJW3zTppOdNDWtKUtux).
# Settings pinned: speed 1.0, style 0.5, stability 0.5, similarity_boost 0.75.

set -euo pipefail

JORDAN_VOICE_ID="4uJW3zTppOdNDWtKUtux"

# next_voice_id — always returns Jordan regardless of last voice argument.
next_voice_id() {
  echo "$JORDAN_VOICE_ID"
}

# tts_render <text> <voice_id> <out_path>
tts_render() {
  local text="$1"
  local voice_id="$2"
  local out="$3"

  if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
    echo "ERROR: ELEVENLABS_API_KEY is not set." >&2
    return 1
  fi

  mkdir -p "$(dirname "$out")"

  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({
  'text': sys.argv[1],
  'model_id': 'eleven_multilingual_v2',
  'voice_settings': {
    'stability': 0.5,
    'similarity_boost': 0.75,
    'style': 0.5,
    'use_speaker_boost': True,
    'speed': 1.0
  }
}))
" "$text")

  local http_status
  http_status=$(curl -sS -o "$out" -w "%{http_code}" \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/${voice_id}" \
    -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Accept: audio/mpeg" \
    --data "$payload")

  if [ "$http_status" != "200" ]; then
    echo "ERROR: ElevenLabs returned HTTP $http_status — body at $out" >&2
    return 1
  fi

  echo "$out"
}

# If script run directly, allow CLI usage: elevenlabs.sh render "text" voice_id out.mp3
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cmd="${1:-}"
  case "$cmd" in
    next) next_voice_id "${2:-}" ;;
    render) tts_render "$2" "$3" "$4" ;;
    *) echo "usage: $0 {next [last_voice]|render <text> <voice_id> <out>}" >&2; exit 2 ;;
  esac
fi
