---
name: morning-content-routine
description: Run the full content pipeline automatically — research, ideate, script, render voiceover, compose video, post to Slack for approval. Polls for reply up to 2 hours.
---

# Morning Content Routine

One command. Three videos. Approval via Slack `#content-approval`.

Runs research → ideation → scripting → ElevenLabs TTS → Remotion render → Slack delivery. Polls Slack for your reply. Nothing gets posted — `/post-content` handles that after approval.

Designed to run headless via a CC Routine (CronCreate) Mon/Wed/Fri 7:30am Australia/Sydney. No terminal interaction needed.

---

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Produces mp3 + mp4 + Slack preview, but sets `content_scripts.status='dry_run'` and skips any post-approval DB updates. |
| `--single-video` | Only process the top-scoring idea (1 video instead of 3). Useful for first-run validation. |

Both flags can be combined: `/morning-content-routine --dry-run --single-video`.

---

## Environment

Slack credentials loaded from `~/.slack-bot-config.json`:
```json
{
  "bot_token": "...",
  "channels": { "approval": "C0ATT8B8EA2", "posted": "C0ATT8D913Q", "alerts": "C0ATT8JPU2J", "briefs": "C0AU87RMW49" }
}
```
`ELEVENLABS_API_KEY` must be exported in the environment.

If either is missing, exit immediately with a stdout error.

---

## Before Running

Read these files silently (do not output until Step 4):
1. `content-engine/CLAUDE.md` — pillars, keywords, voice, platforms
2. `content-engine/reference/avatar.md`
3. `content-engine/reference/scripting-voice.md`
4. `content-engine/reference/hook-swipe-file.md`
5. `content-engine/reference/viral-content-patterns.md`

---

## Step 1 — Research

Run `/daily-content-researcher` logic inline:

Use WebSearch for each:
1. `site:reddit.com r/habittracking`
2. `site:reddit.com r/fitness habit tracking`
3. `site:reddit.com r/selfimprovement daily routine consistency`
4. `habit tracking app review streak 2026`
5. `supplement tracking app stack 2026`
6. `"why people quit habits" OR "habit failure" research 2026`
7. `fitness accountability app group workout 2026`

Score each result 1-5 on: audience fit, demo-ability, hook potential, pillar match, freshness. Drop anything under 15/25.

Save top 10 to Supabase `content_ideas` with `status='researched'`.

---

## Step 2 — Ideate

Take top 3 scoring ideas (or top 1 if `--single-video`).

For each, generate 5 video variations. All variations use the **screen-record + ElevenLabs voiceover + Remotion** format — no talking head, no on-camera founder. Talking-head and founder formats are deprecated.

```markdown
Variation N:
- Archetype: [from viral-content-patterns.md]
- Hook angle: [one-line hook]
- Audience: MACRO / MICRO / BOTH
- Thesis: [one sentence]
- Platform: [best platform]
- Production time: 5 / 15 / 30 min
```

Score: hook strength (40%), production speed (30%), platform fit (30%). Select highest-scoring variation per topic. Store all 5 for later rejection handling.

Save to Supabase `content_scripts` with `status='ideated'`, `format_type='screen_record'`.

> **Written posts:** Structure the `full_text` with clear double-line-breaks between paragraphs — each paragraph becomes one carousel slide. Write enough content to fill 3-6 slides (roughly 400-800 words total). Do not truncate — the full article will be split across carousel images.

---

## Step 3 — Script

For each selected video:

> **Written posts:** Structure the `full_text` with clear double-line-breaks between paragraphs — each paragraph becomes one carousel slide. Write enough content to fill 3-6 slides (roughly 400-800 words total). Do not truncate — the full article will be split across carousel images.

### 3a. Generate 6 hooks

Pull from `hook-swipe-file.md`. Each hook: one sentence, ≤15 words, info gap or emotion, respects `scripting-voice.md` (no banned words, no warm-up). Rank by scroll-stopping power (specificity > tension > brevity). Auto-select #1.

### 3b. Build the speaking script

The ElevenLabs voiceover needs **plain prose with natural pauses**, not a filming card. Join:
```
<hook>

<point 1>

<point 2>

<point 3>

<close>

<cta>
```

Each block separated by a blank line = natural pause in ElevenLabs output. Keep total speaking time 45–90s (roughly 120-250 words at natural pace). The voiceover must fill the majority of the video duration — write enough script to run from the opening second to near the end. If in doubt, write more not less.

### 3c. Save

```sql
UPDATE content_scripts
SET hook_options = '[JSON array of 6 hooks]',
    chosen_hook = '[Hook #1]',
    filming_card = '[full script with line breaks]',
    status = 'scripted'
WHERE id = [script_id];
```

---

## Step 3.5 — ElevenLabs TTS

For each scripted video:

### Pick next voice

```bash
LAST_VOICE=$(mcp_supabase_execute_sql "SELECT voice_id FROM content_scripts WHERE voice_id IS NOT NULL ORDER BY created_at DESC LIMIT 1;" | jq -r '.[0].voice_id // empty')
VOICE_ID=$(bash content-engine/lib/elevenlabs.sh next "$LAST_VOICE")
```

Rotation order: Hans Wilmar → Jordan → Dave → Charlotte → Emma → Hannah. First-ever run defaults to Hans.

### Render mp3

```bash
OUT="content-engine/out/vo-${SCRIPT_ID}.mp3"
bash content-engine/lib/elevenlabs.sh render "$SPEAKING_SCRIPT" "$VOICE_ID" "$OUT"
```

Pinned settings: speed 1.0, style 0.5, stability 0.5, similarity_boost 0.75. **Never change.**

### Record to Supabase

```sql
UPDATE content_scripts
SET voice_id = '<voice_id>',
    voiceover_path = '<absolute path to mp3>'
WHERE id = <script_id>;
```

---

## Step 3.6 — Remotion render

Compose the Feature Demo video with the voiceover + a real screen clip (image or video).

### Pick a screen clip

The composition supports:
- **Images** (`.png` / `.jpg` / `.webp`) — rendered via `<Img>` with a slow Ken-Burns zoom
- **Videos** (`.mp4` / `.mov` / `.webm`) — rendered via `<OffthreadVideo>`

**Auto-discovery (default):** scan `~/Desktop/OnTrack screenshots/` for files matching `Simulator Screenshot*.png` and pick the most recently modified one. Copy it into `~/Desktop/OnTrack-Reel/public/screenshots/` with a stable name and pass the relative path.

```bash
SCREENSHOT_DIR="$HOME/Desktop/OnTrack screenshots"
PUBLIC_DIR="$HOME/Desktop/OnTrack-Reel/public/screenshots"
mkdir -p "$PUBLIC_DIR"

LATEST=$(ls -t "$SCREENSHOT_DIR"/Simulator\ Screenshot*.png 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  DEST_NAME="auto-${SCRIPT_ID}.png"
  cp "$LATEST" "$PUBLIC_DIR/$DEST_NAME"
  SCREEN_CLIP="screenshots/$DEST_NAME"
  SCREEN_STATIC=true
else
  SCREEN_CLIP=""
  SCREEN_STATIC=false
fi
```

If you want to override for a specific hook/pillar combo, set `SCREEN_CLIP` to a pre-staged filename under `public/screenshots/` (e.g. `screenshots/daily-actions-complete.png` is the hero for the habit-tracking pillar).

If `SCREEN_CLIP` is empty, the composition falls back to the OnTrack-branded placeholder.

### Render

```bash
PROPS=$(python3 -c "
import json, sys
props = {
  'voiceoverPath': sys.argv[1],
  'screenClipPath': sys.argv[2] or None,
  'screenClipIsStatic': sys.argv[3].lower() == 'true',
  'hookText': sys.argv[4],
  'points': [sys.argv[5], sys.argv[6], sys.argv[7]],
  'ctaText': 'Available now on iOS — link in bio',
}
print(json.dumps(props))
" "$VOICEOVER_REL" "$SCREEN_CLIP" "$SCREEN_STATIC" "$HOOK" "$P1" "$P2" "$P3")

OUT_MP4="$HOME/Desktop/OnTrack/OnTrack/content-engine/out/video-${SCRIPT_ID}.mp4"
cd ~/Desktop/OnTrack-Reel
npx remotion render FeatureDemo "$OUT_MP4" --props="$PROPS" 2>&1 | tail -20
```

`voiceoverPath` is the filename under `public/voiceovers/` (after copying the mp3 produced in Step 3.5 into that folder).

Record to Supabase:

```sql
UPDATE content_scripts SET video_path = '<absolute path to mp4>' WHERE id = <script_id>;
```

---

## Step 4 — Send approval to Slack `#content-approval`

For each rendered video, generate Instagram + TikTok captions only (full 6-platform captions come later via `/post-content`).

### Caption rules

**Instagram** — hook first line, 3-5 lines max, CTA `Available now on iOS — link in bio`, 5-8 hashtags.
**TikTok** — hook first line, 2-3 sentences, CTA `Link in bio`, 2-3 hashtags.

### Post to Slack

```bash
source content-engine/lib/slack.sh

HEADER="CONTENT ENGINE — $(date +%Y-%m-%d)
$COUNT video(s) ready to review"

slack_post_message approval "$HEADER"

for each video:
  # Upload the mp4 with the filming card + captions as initial_comment
  COMMENT="VIDEO $N of $COUNT
HOOK: $HOOK
FORMAT: $ARCHETYPE / screen-record / ~${DURATION}s
PILLAR: $PILLAR | AUDIENCE: $AUDIENCE | SCORE: $SCORE/25
VOICE: $VOICE_NAME

IG CAPTION:
$IG_CAPTION

TIKTOK CAPTION:
$TT_CAPTION"

  slack_upload_file approval "$VIDEO_PATH" "$COMMENT"
done

FOOTER="Reply in this channel with:
APPROVE ALL | APPROVE 1 2 | REJECT 1 | CHANGE 2: instruction | SKIP TODAY"

slack_post_message approval "$FOOTER"
```

If running with `--dry-run`, still post to Slack — the dry-run flag only gates the downstream DB status update and the Post Bridge call in `/post-content`.

Record the posting timestamp so `slack_poll_reply` only sees messages after the prompt:

```bash
POLL_SINCE=$(date +%s)
```

---

## Step 5 — Poll Slack for reply

```bash
REPLY=$(bash content-engine/lib/slack.sh poll approval "$POLL_SINCE" 30 240 || echo TIMEOUT)
```

### On `APPROVE ALL` or `APPROVE [numbers]`

Parse approved numbers. Update:
```sql
UPDATE content_scripts
SET status = CASE WHEN '--dry-run' IS PROVIDED THEN 'dry_run' ELSE 'approved' END
WHERE id IN (<approved_ids>);
```

Post confirmation:
```bash
slack_post_message approval "$N videos added to filming queue. Run /post-content <script_id> when the edit is ready."
```

### On `REJECT [number]`

1. Pull the next highest-scoring variation from Step 2.
2. Re-run Steps 3, 3.5, 3.6 for the replacement.
3. Post updated video to Slack as a reply in the approval thread.
4. Resume polling.

### On `CHANGE [number]: [instruction]`

1. Apply instruction to hook/script, re-run Steps 3.5 + 3.6.
2. Post updated video.
3. Resume polling.

Common instructions: "make the hook more aggressive", "shorter", "use comparison format", "more data", "less salesy".

### On `SKIP TODAY`

```bash
slack_post_message approval "Session closed. Nothing saved."
```
Exit without updating Supabase.

### On timeout (2 hours, no reply)

```bash
slack_post_message alerts "⚠ Morning routine timed out — no reply in #content-approval by $(date)."
```
Ideas/scripts remain in Supabase with `researched`/`scripted` status — they are not lost.

---

## Timing

- Steps 1-3.6 (headless pipeline): 4-6 minutes (dominated by Remotion render)
- Step 5 (polling): up to 2 hours, 30s interval
- Total active user time: under 2 minutes in Slack

---

## Data Layer

Writes: `content_ideas` (Step 1), `content_scripts` (Steps 2, 3, 3.5, 3.6, approval updates)
Reads: all reference files, Supabase, `~/.slack-bot-config.json`, `$ELEVENLABS_API_KEY`
Does NOT write to: `content_posts` — that happens via `/post-content`.

---

## Scheduling

- **System cron (reliable):** `30 7 * * 1,3,5 ~/Desktop/OnTrack/OnTrack/content-engine/run-morning-routine.sh` — fires even when no CC session is running.
- **CC Routine (in-session):** `CronCreate "33 7 * * 1,3,5" "/morning-content-routine"` registered per session; auto-expires after 7 days. Re-register at the start of any long-lived Jarvis session.
- **Manual:** `/morning-content-routine` in any CC session.
- **Via Telegram (Jarvis):** "Run the morning routine" → Jarvis triggers this skill.

> **Scheduling note (2026-04-19):** CronCreate durability did not behave as documented in testing — the session-only / 7-day-expiry path was active despite `durable=true`. Until that's confirmed, system cron remains the authoritative schedule. Both paths invoke the same skill, so duplicate fires are possible but unlikely given the 3-minute cron offset.
