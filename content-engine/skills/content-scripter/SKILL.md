---
name: content-scripter
description: Generate 6 hook options and a complete filming card for each ideated video concept. Voice must match scripting-voice.md exactly.
---

# Content Scripter

Turn ideated concepts into ready-to-film scripts. The output is a filming card — everything Matt needs to pick up his phone and record.

---

## Before Running

Read these files — they are non-negotiable:
1. `content-engine/reference/scripting-voice.md` — voice rules, banned words, sentence style
2. `content-engine/reference/hook-swipe-file.md` — hook templates
3. `content-engine/reference/avatar.md` — who we're talking to

---

## Step 1 — Pull Ideated Scripts

Query Supabase:

```sql
SELECT cs.*, ci.title, ci.ontrack_angle, ci.pillar
FROM content_scripts cs
JOIN content_ideas ci ON cs.idea_id = ci.id
WHERE cs.status = 'ideated'
ORDER BY cs.created_at DESC
LIMIT 5;
```

---

## Step 2 — Generate 6 Hooks

For each ideated script, generate **6 hook options**. Each hook must:

- Be one sentence, max 15 words
- Create an information gap or emotional reaction
- Follow the rules in `scripting-voice.md` (no banned words, no warm-up, no questions that are too vague)
- Use a different template from `hook-swipe-file.md` where possible

Rank hooks 1-6 by estimated scroll-stopping power. Criteria:
- Specificity (numbers and named things beat vague claims)
- Tension (negative framing beats positive on short-form)
- Speed (shorter hooks beat longer ones)

---

## Step 3 — Build Filming Card

For each script, produce a filming card:

```markdown
# FILMING CARD

## Meta
- **Topic:** [from content_ideas.title]
- **Archetype:** [from content_scripts.archetype]
- **Platform:** [primary platform]
- **Audience:** MACRO / MICRO / BOTH
- **Pillar:** [content pillar]
- **Estimated length:** [15s / 30s / 45s / 60s]
- **Format:** [Screen record / Text overlay / Mixed] — all video is screen recording of the OnTrack iOS app + AI voiceover (ElevenLabs) composed in Remotion. No talking-head or on-camera founder formats.

## Hook (say this first)
> "[Chosen hook — #1 ranked]"

## Body (3 talking points)

### Point 1
> "[Specific claim or data point. One sentence.]"
- Visual: [what's on screen — app screenshot, face, text overlay]

### Point 2
> "[Supporting evidence or example. One sentence.]"
- Visual: [what's on screen]

### Point 3
> "[The OnTrack connection — how the app solves this. One sentence.]"
- Visual: [show the app feature if relevant]

## Close
> "[Final line — punchy, ties back to hook]"

## CTA
> "[Platform-appropriate CTA from scripting-voice.md]"

## Alt Hooks (for A/B testing)
1. "[Hook #2]"
2. "[Hook #3]"

## Notes
- [Any filming tips — lighting, angle, app state to prepare]
- [Specific screen to have open if doing a demo]
```

### Script Rules

1. Total speaking time: 15-60 seconds. If longer, cut.
2. Every point must be one sentence. If it takes two, the point is too broad.
3. Point 3 must connect to OnTrack specifically — but naturally, not forced
4. Body text must pass the voice check against `scripting-voice.md`
5. Visuals must be specific — "show the app" is not enough. Which screen? Which feature?

---

## Step 4 — Save to Supabase

Update the script record:

```sql
UPDATE content_scripts
SET hook_options = '[JSON array of 6 hooks]',
    chosen_hook = '[Hook #1]',
    filming_card = '[Full filming card as markdown]',
    status = 'scripted'
WHERE id = [script_id];
```

---

## Step 5 — Output

Print each filming card in full. Then summarise:

```
Scripted [X] videos | Ready to film
Top hook: "[best hook across all cards]"
```

---

## Data Layer Notes

Reads from: `content_scripts` + `content_ideas` (Supabase)
Writes to: `content_scripts` (Supabase) — updates status to `scripted`
