---
name: competitor-analyst
description: Research any competitor app or creator handle. Analyse posting frequency, content formats, top posts, hook patterns, and engagement. Identify gaps OnTrack can own. Save a competitor brief.
---

# Competitor Analyst

Research a competitor's content strategy. Find what they're doing, what's working, and — most importantly — what they're NOT covering.

---

## Input

Accepts one argument: a competitor name, app name, or social handle.

Examples:
- `/competitor-analyst GymRats`
- `/competitor-analyst @98gym`
- `/competitor-analyst Streaks app`

No hardcoded list — accepts any input.

---

## Known Competitors (for reference, not a limit)

**Apps:** GymRats, Streaks, Habitica, Gentler Streak, HabitNow
**Creators/Accounts:** @98gym, @atora, @theyard

---

## Step 1 — Research

Use WebSearch to gather data on the competitor:

### For Apps
- Search: `[app name] instagram` — find their social accounts
- Search: `[app name] tiktok` — find TikTok presence
- Search: `[app name] app store reviews` — what users love and hate
- Search: `[app name] vs` — see what comparisons exist
- Search: `site:reddit.com [app name]` — community sentiment

### For Creator Handles
- Search: `[handle] instagram` OR `[handle] tiktok` — find their profiles
- Search: `[handle] content` — what topics do they cover?
- Fetch their profile page if possible to see recent post topics

---

## Step 2 — Analyse

Build a competitor profile:

```markdown
## Competitor Brief: [Name]

### Identity
- **Type:** App / Creator / Gym / Brand
- **Platforms active on:** [list]
- **Estimated follower count:** [per platform if findable]
- **Posting frequency:** [X posts/week estimate]

### Content Strategy
- **Primary format:** [Reels / Talking head / Screen records / Carousels / Text posts]
- **Content pillars they cover:** [list their themes]
- **Tone:** [Describe their voice — motivational? educational? raw? polished?]
- **Hook style:** [Do they lead with hooks? What type?]

### Top Performing Content
List 3-5 posts or topics that appear to perform well (high engagement, many comments, shared widely):
1. [Topic/post description] — why it likely worked
2. [Topic/post description] — why it likely worked
3. [Topic/post description] — why it likely worked

### Engagement Patterns
- **What gets engagement:** [themes, formats, or styles that work for them]
- **What falls flat:** [topics or formats that don't seem to perform]
- **Community response:** [Are people positive? Negative? Asking questions?]

### App Store Sentiment (if app)
- **Common praise:** [what users love]
- **Common complaints:** [what users hate — these are our content opportunities]
- **Feature requests:** [what people want that OnTrack might already have]
```

---

## Step 3 — Gap Analysis

The most important section. Identify topics and angles the competitor is NOT covering that OnTrack could own:

```markdown
### Gaps — Topics They're NOT Covering

1. **[Gap topic]**
   - Why it matters: [audience demand signal]
   - OnTrack angle: [how we'd cover this]
   - Suggested archetype: [from viral-content-patterns.md]

2. **[Gap topic]**
   - Why it matters: [audience demand signal]
   - OnTrack angle: [how we'd cover this]
   - Suggested archetype: [from viral-content-patterns.md]

3. **[Gap topic]**
   - Why it matters: [audience demand signal]
   - OnTrack angle: [how we'd cover this]
   - Suggested archetype: [from viral-content-patterns.md]
```

### Common Gaps to Look For
- Group accountability content (most apps are solo-focused)
- Supplement tracking content (very underserved niche)
- Real data / before-after tracking content (most apps don't show this)
- Founder story / building in public (most apps are faceless)
- Honest comparisons (most competitors avoid mentioning each other)

---

## Step 4 — Save

Create the competitor brief at:
```
content-engine/reference/competitors/[name-slug].md
```

Create the `competitors/` directory if it doesn't exist:
```bash
mkdir -p content-engine/reference/competitors
```

---

## Step 5 — Feed Ideas to Pipeline

For each gap identified, optionally insert into `content_ideas`:

```sql
INSERT INTO content_ideas (title, source_url, source_type, trending_reason, ontrack_angle, pillar, best_platform, suggested_hook, audience_tier, research_score, status)
VALUES ([gap_topic], 'competitor-analysis', 'competitor_gap', [why_it_matters], [ontrack_angle], [pillar], [platform], [suggested_hook], 'both', 20, 'researched');
```

---

## Step 6 — Report

```
Competitor Brief: [Name]
Platforms: [list] | Posting: ~[X]/week | Gaps found: [X]
Brief saved to content-engine/reference/competitors/[slug].md
[X] gap ideas added to content_ideas pipeline
```

---

## Data Layer Notes

Writes to: `content-engine/reference/competitors/` (files) + `content_ideas` (Supabase, optional)
