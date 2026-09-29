#!/usr/bin/env bash
# Test entry point for .prime-job.json: runs the OnTrackTests unit target.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild test \
  -project OnTrack.xcodeproj \
  -scheme OnTrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:OnTrackTests
