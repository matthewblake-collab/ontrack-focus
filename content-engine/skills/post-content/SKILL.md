---
name: post-content
description: Generate platform-specific captions, get user approval, then upload media and dispatch a multi-platform post via the real Post Bridge API. Defaults to dry-run if no key.
---

# Post Content

Full posting pipeline: captions → approve → Post Bridge media upload → Post Bridge post → log.

Post Bridge replaces the legacy Computer Use / Playwright flow. Two API calls (upload + post), nine platforms available, parallel dispatch.

API ref: https://api.post-bridge.com/reference. Helper: `content-engine/lib/postbridge.sh`.

---

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Print the full payload that would be sent, skip every HTTP call, skip `content_posts` insert. |
| `--draft`   | Creates the post on Post Bridge with `is_draft=true` so you can review in their dashboard before scheduling. |

If `$POST_BRIDGE_API_KEY` is **not set**, the skill automatically runs in dry-run mode and surfaces a one-line warning.

---

## Before Running

Read:
1. `content-engine/reference/scripting-voice.md`
2. `content-engine/CLAUDE.md`
3. `content-engine/reference/hook-swipe-file.md`
4. `content-engine/lib/postbridge.sh` — for the exact helper functions available

---

## Stage 1 — Input

Ask the user:
1. **Video file path** — absolute path to the edited mp4. Confirm exists.
2. **Supabase script record** — pass `content_scripts.id` if available. Skill reads `chosen_hook`, `filming_card`, `voice_id`, and joins `content_ideas.pillar`. If no record, user describes topic; `script_id` on the post record will be null.

---

## Stage 2 — Captions

### 2a. Source script text

If `content_scripts.filming_card` exists — use it. No transcription needed.

Otherwise fall back to Whisper:
```bash
whisper "<video_path>" --output_format txt --output_dir /tmp/whisper-out
```
Install: `pip install openai-whisper`.

### 2b. Generate 6 platform captions

Respect `scripting-voice.md` banned-word list in every caption.

| Platform | Shape |
|---|---|
| Instagram | Hook line, 3-5 lines, CTA `Available now on iOS — link in bio`, 5-8 hashtags. |
| TikTok    | Hook line, 2-3 sentences, CTA `Link in bio`, 2-3 hashtags. |
| Facebook  | Slightly longer, question to spark comments, CTA `Available now on iOS`, 3-5 hashtags. |
| LinkedIn  | 3-5 short paragraphs, founder framing "I built…", direct App Store URL acceptable, 2-3 hashtags. |
| X/Twitter | 1-2 lines, ≤280 chars, no hashtags in main tweet. |
| Threads   | Conversational, 2-3 sentences, no hashtags. |

---

## Stage 3 — Approval

Display all 6 captions (platform headers):

```markdown
# Post Preview — [Topic / Hook]

## Instagram
[caption]

## TikTok
…etc for all 6
```

Ask:
```
Reply with:
- APPROVE ALL → post to every connected account for these 6 platforms
- SKIP [platform] → exclude one (e.g. SKIP linkedin)
- EDIT [platform]: [new caption] → replace a caption before posting
- CANCEL → abort
```

Never proceed past Stage 3 without explicit APPROVE.

---

## Stage 4 — Post Bridge dispatch

### 4a. Determine mode

```bash
DRY_RUN=false
if [[ "$*" == *"--dry-run"* ]] || [ -z "${POST_BRIDGE_API_KEY:-}" ]; then
  DRY_RUN=true
fi
IS_DRAFT=false
[[ "$*" == *"--draft"* ]] && IS_DRAFT=true
```

### 4b. List connected accounts

Post Bridge addresses posts by **numeric social-account IDs**, not platform names. First call `pb_accounts` to build a platform → account_id map:

```bash
source content-engine/lib/postbridge.sh
ACCOUNTS_JSON=$(pb_accounts)
```

Response shape (confirmed 2026-04-19): `{ "data": [{ "id", "platform", "username" }, ...], "meta": {...} }`. Unwrap `.data`.

Build a mapping like:
```json
{
  "instagram":         57697,
  "twitter":           57698,
  "tiktok":            57699,
  "facebook":          57700,
  "linkedin_personal": 57701,
  "linkedin_company":  57702,
  "threads":           57703
}
```

Multiple accounts on the same platform (e.g. LinkedIn personal + company) are **both valid** — the caller decides which to include based on the content-pillar / audience tier. Default for routine pipeline: company page only. Founder-voice pieces (pillar: `why_people_fail` with personal framing): both LinkedIn accounts.

Drop any platform the user `SKIP`-ped in Stage 3. If a platform the user wants has no matching Post Bridge account, abort with a clear message — do not silently proceed.

### 4c. Upload the mp4 (once)

```bash
MEDIA=$(pb_upload "$VIDEO_PATH")
MEDIA_ID=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['media_id'])" "$MEDIA")
```

If `DRY_RUN`, skip the upload — use the sentinel `"mda_DRY_RUN"`.

### 4d. Build per-platform configuration

Post Bridge accepts one `caption` (default) plus a `platform_configurations` object for per-platform overrides. Use the Instagram caption as the default (longest, most expressive), and populate overrides for the rest:

```python
platform_configs = {
  "tiktok":   {"caption": tiktok_caption},
  "linkedin": {"caption": linkedin_caption},
  "twitter":  {"caption": x_caption},
  "facebook": {"caption": facebook_caption},
  "threads":  {"caption": threads_caption},
}
```

The exact keys inside each platform's config block follow the API ref (some platforms support `title`, `visibility`, `first_comment`, etc.). Keep it to `caption` for v1; expand later as needed.

### 4e. Assemble and dispatch

```bash
ACCOUNTS_CSV="101,102,103,104,105,106"   # from 4b, filtered by user SKIPs
PLATFORM_CONFIGS_JSON='{ ... from 4d ... }'
PAYLOAD=$(pb_build_payload "$IG_CAPTION" "$MEDIA_ID" "$ACCOUNTS_CSV" "$PLATFORM_CONFIGS_JSON")

# If draft flag set, splice in is_draft
if $IS_DRAFT; then
  PAYLOAD=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d['is_draft']=True; print(json.dumps(d))" "$PAYLOAD")
fi
```

#### DRY RUN path

Print:
```
═══ POST BRIDGE DRY RUN ═══
No HTTP call made. POST_BRIDGE_API_KEY is <unset|present, --dry-run supplied>.
Payload that would have been sent to POST /v1/posts:
<pretty-printed PAYLOAD>
═══════════════════════════
```
Skip Stage 5.

#### LIVE path

```bash
RESPONSE=$(pb_create_post "$PAYLOAD")
POST_ID=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('id',''))" "$RESPONSE")
```

Expected response (per API ref): an object with `id`, `status`, `results[]` per connected account. **Fail loud** on any non-2xx — never silently drop a platform.

Persist the PB post id on the script row so the approval daemon can locate the draft later (applies to both `--draft` and live runs):

```sql
UPDATE content_scripts SET pb_post_id = '<POST_ID>' WHERE id = <script_id>;
```

### 4f. Mirror to Slack `#content-posted`

```bash
source content-engine/lib/slack.sh
slack_post_message posted "✅ Posted via Post Bridge
Hook: $CHOSEN_HOOK
Media ID: $MEDIA_ID
Post ID: $POST_ID
Accounts: $ACCOUNTS_CSV
Draft: $IS_DRAFT"
```

---

## Stage 5 — Log to Supabase

Insert rows for **successfully dispatched** platforms only (any per-account `results[]` entry with a non-error status from Post Bridge):

```sql
INSERT INTO content_posts (script_id, title, platform, hook_type, content_pillar, caption, hashtags, posted_at, status)
VALUES
  (<script_id>, <hook>, 'instagram', <hook_type>, <pillar>, <ig_caption>, <ig_hashtags>, NOW(), 'published'),
  ...;
```

Then:
```sql
UPDATE content_scripts SET status = 'posted' WHERE id = <script_id>;
```

### Classify

- **hook_type** — match `chosen_hook` against templates in `hook-swipe-file.md` (curiosity, failure, demo, data, comparison, etc.).
- **content_pillar** — match `content_ideas.pillar` value (habit_science, fitness_tips, feature_demo, user_wins, app_comparison, why_people_fail).

---

## Stage 6 — Confirm

```
Posted via Post Bridge → <N> platforms: <list>
Skipped: <list or "none">
Errored: <list or "none">
Post Bridge id: <post_id>
Script status: posted
Engagement data will populate via CSV → /shortform-analysis.
```

---

## Error Handling

| Error | Action |
|-------|--------|
| `$POST_BRIDGE_API_KEY` unset | Auto dry-run, one-line warn, continue through Stage 4 payload printout. |
| Video file not found | Abort before Stage 2. |
| Whisper missing AND no filming_card | Ask user to install or supply script text. |
| `pb_accounts` returns empty | User hasn't connected accounts — tell them to visit post-bridge.com/dashboard/connections. |
| Requested platform has no connected account | Abort, name the missing platform. |
| `pb_upload` returns non-200 on PUT | Show body, abort — don't try to post with an invalid media_id. |
| `pb_create_post` returns 4xx | Show response, tell user to verify key / account status. |
| Per-platform error in `results[]` | Log to Slack, include in Stage 5's skipped list, continue for the successful platforms. |
| Slack notification fails | Warn but do not roll back — the post itself succeeded. |

---

## Data Layer

Reads: `content_scripts` + `content_ideas` (Supabase), video file (disk), transcript (Whisper fallback), `pb_accounts` → Post Bridge account IDs
Writes: `content_posts` (Supabase), Slack `#content-posted`
Env: `POST_BRIDGE_API_KEY` (optional — absent → dry-run)
