---
name: daily-content-researcher
description: Search Reddit, X/Twitter, App Store reviews, and fitness newsletters for trending topics in the habit/fitness niche. Output a ranked list of content ideas saved to Supabase.
---

# Daily Content Researcher

Find what the OnTrack audience is talking about right now. Surface topics with the highest short-form video potential.

---

## Before Running

Read these files for context:
1. `content-engine/CLAUDE.md` — pillars, keywords, voice rules
2. `content-engine/reference/avatar.md` — who we're making content for

---

## Step 1 — Search

Use WebSearch to scan these sources for activity in the last 24-48 hours:

### Reddit
Search queries (run each separately):
- `site:reddit.com r/habittracking` — what problems are people posting about?
- `site:reddit.com r/fitness habit tracking` — fitness-specific habit discussions
- `site:reddit.com r/selfimprovement daily routine` — routine and consistency threads
- `site:reddit.com r/supplements tracking` — supplement logging pain points

### X / Twitter
- `habit tracking app` — what are people saying about existing apps?
- `fitness streak` OR `workout streak` — streak-related content performing well?
- `supplement stack tracking` — anyone discussing this niche?

### App Store Reviews
- `site:apps.apple.com "habit" OR "streak" OR "fitness tracking"` — recent reviews mentioning pain points
- Search for reviews of: Streaks, Habitica, GymRats, HabitNow — what are people complaining about?

### Newsletters & Blogs
- `habit science 2026` — recent research or articles
- `fitness app review` — recent app comparisons or roundups

---

## Step 2 — Filter

For each result, evaluate against these criteria:

| Criteria | Score 1-5 |
|----------|-----------|
| **Audience fit** — would OnTrack's target audience care? | |
| **Demo-ability** — can we show OnTrack solving this on screen? | |
| **Hook potential** — can this become a scroll-stopping first line? | |
| **Pillar match** — which content pillar does this fit? | |
| **Freshness** — is this trending now or evergreen? | |

Drop anything scoring below 15/25 total.

---

## Step 3 — Rank and Output

Produce a ranked list of the top 10 topics:

```markdown
## Daily Content Research — YYYY-MM-DD

### 1. [Topic Title]
- **Source:** [Reddit thread / tweet / review]
- **Why it's trending:** [1 sentence]
- **OnTrack angle:** [How OnTrack solves or relates to this]
- **Suggested pillar:** [Habit Science / Fitness Tips / Feature Demo / etc.]
- **Best platform:** [Instagram / TikTok / LinkedIn / X / Threads]
- **Hook potential:** [Draft hook in one line]
- **Audience:** MACRO / MICRO / BOTH
- **Score:** [X/25]
```

---

## Step 4 — Save to Supabase

Insert each topic into the `content_ideas` table:

```sql
INSERT INTO content_ideas (title, source_url, source_type, trending_reason, ontrack_angle, pillar, best_platform, suggested_hook, audience_tier, research_score, status)
VALUES (..., 'researched');
```

Set status to `researched` for all new entries.

---

## Step 5 — Report

Print a summary:

```
Content Research — YYYY-MM-DD
[X] topics found | Top topic: [title] | Top pillar: [pillar]
Saved to content_ideas table.
```

---

## Data Layer Notes

This skill writes to: `content_ideas` (Supabase)
Future: when Airtable is added, swap the INSERT for an Airtable API call. Skill logic stays the same.
