---
paths: ["**/scripts/*.py", "**/ontrack-website/**"]
---

## Marketing / Content engine
- **Format:** Screen recording of the OnTrack iOS app + AI voiceover (ElevenLabs Voice Library) + Remotion compositions. No talking heads. No on-camera founder content. No HeyGen.
- **Posting:** Post Bridge unified API (when wired) — replaces Computer Use Playwright posting.
- **Shot list:** `~/.OnTrack-Marketing/recording-shot-list.md`
- **Stack doc:** `~/.OnTrack-Marketing/stack.md`
- **Pivot rationale:** `~/Brain/02-projects/ontrack/marketing-pivot-2026-04-18.md`

## Content Pipeline
- **Remotion component rules:** Always use `OffthreadVideo` (not `Video`) for iOS screen recordings. Normalise iOS screen recording metadata with ffmpeg before importing. Use `staticFile()` for all audio paths. Use `type` (not `interface`) for Remotion component prop definitions to avoid TypeScript errors.
- **Render output path (hard rule):** All Remotion renders must output to `~/Brain/02-projects/ontrack/videos/` — never `~/Desktop` or any path outside `~/Brain`. The `com.matt.approval-webhook` launchd agent runs under TCC sandbox that blocks Desktop access; attempting to `pb_upload` an mp4 from `~/Desktop/OnTrack-Reel/out/` raises `[Errno 1] Operation not permitted` and fails the approve button. `~/Brain/` is inside the user's home with regular permissions and is the only safe location for pipeline-bound artifacts.
- **Correct render command:** `cd ~/Desktop/OnTrack-Reel && npx remotion render <Composition> ~/Brain/02-projects/ontrack/videos/<n>.mp4 --props='{"key":"value"}'`
- **Queue path must match:** Every item in `video_queue.json` `path` field must live under `~/Brain/02-projects/ontrack/videos/`. `scripts/pipeline_health.sh` will flag any queue item whose path fails `Path.is_file()`.
- **Existing Desktop renders:** Any `.mp4` still under `~/Desktop/OnTrack-Reel/out/` must be copied (not symlinked — TCC still blocks the target) into `~/Brain/02-projects/ontrack/videos/` before being queued.

## Python Compatibility
Environment uses Python 3.9.6. Always add `from __future__ import annotations` at the top of new Python files. Never use PEP 604 union syntax (X | Y) in runtime-evaluated contexts — use Optional[X] or Union[X, Y] from typing instead.
- Verify Python version with `python3 --version` before using modern syntax in new scripts

## Observer Agent Output Format
When acting as the observer/memory agent, always use <summary> tags (never <observation> tags) and keep responses under 500 output tokens. If primary session context is too long, summarise at file/feature level — never enumerate every tool call.

## React/Vite rules
- Never add hardcoded `<script>` tags to index.html — Vite handles bundling
- For framer-motion: `transition.ease` must be a string value like `'easeInOut'`, NOT a custom bezier array

## Visual Docs Auto-Update
- After any implementation that changes pipeline architecture, services, or Jarvis, call `visual_docs_updater.update()` via `brain_updater` — this is already wired
- Item titles flowing through `pending_implementations.json` must be clean user-facing copy — they appear verbatim in HTML docs
