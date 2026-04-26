---
name: content-ideator
description: Take researched topics from Supabase and generate 5 distinct video variations per topic using viral content archetypes. Update status to ideated.
---

# Content Ideator

Turn raw research into filmable video concepts. Every topic gets 5 distinct angles — different enough that each could be its own video.

---

## Before Running

Read these files:
1. `content-engine/reference/viral-content-patterns.md` — the 8 archetypes
2. `content-engine/reference/avatar.md` — macro vs micro audience
3. `content-engine/reference/hook-swipe-file.md` — hook templates for inspiration

---

## Step 1 — Pull Researched Ideas

Query Supabase for ideas with status `researched`:

```sql
SELECT * FROM content_ideas WHERE status = 'researched' ORDER BY research_score DESC LIMIT 10;
```

If no results, tell the user to run `/daily-content-researcher` first.

---

## Step 2 — Generate Variations

For each topic, generate **5 distinct video variations**. Each variation must use a different archetype from `viral-content-patterns.md`.

Format per variation:

```markdown
### Variation [N]: [Archetype Name]
- **Format:** [Reel / Screen record / Text overlay / Carousel] — talking-head and on-camera founder formats are deprecated; all video is screen recording of the OnTrack app + AI voiceover via Remotion
- **Hook angle:** [One-line hook adapted from hook-swipe-file.md]
- **Target audience:** MACRO / MICRO / BOTH
- **Thesis:** [The single point this video makes — one sentence max]
- **Platform:** [Best platform for this format]
- **Estimated production time:** [5 min / 15 min / 30 min]
```

### Variation Rules

1. No two variations should use the same archetype
2. At least one variation must be a screen-record demo (fast to produce)
3. At least one variation must target MACRO audience
4. At least one variation must target MICRO audience
5. Every variation must have a thesis that fits in one sentence — if it doesn't, the idea is too broad

### Archetype Prioritisation

Use this priority based on what performs:
1. Why You're Failing (highest engagement)
2. Myth Bust (high shares)
3. Speed Setup (highest conversion)
4. Feature Drop (good for MICRO)
5. Comparison (good for search)
6. Before/After Data (trust building)
7. Impossible Demo (attention grabbing)
8. User Win (social proof)

---

## Step 3 — Save to Supabase

For each variation, insert into `content_scripts`:

```sql
INSERT INTO content_scripts (idea_id, archetype, format_type, hook_angle, target_audience, thesis, best_platform, production_time, status)
VALUES (..., 'ideated');
```

Update the parent idea status:

```sql
UPDATE content_ideas SET status = 'ideated' WHERE id = [idea_id];
```

---

## Step 4 — Output

Print a summary per topic:

```markdown
## [Topic Title]
5 variations generated:
1. [Archetype] — [Hook angle] — [Platform] — [MACRO/MICRO]
2. ...
3. ...
4. ...
5. ...

Recommended to script first: Variation [N] (highest hook potential + fastest production)
```

---

## Data Layer Notes

Reads from: `content_ideas` (Supabase)
Writes to: `content_scripts` (Supabase)
Future: swap Supabase queries for Airtable API calls. Skill logic unchanged.
