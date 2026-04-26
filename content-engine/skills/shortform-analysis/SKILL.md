---
name: shortform-analysis
description: Parse CSV exports from Instagram and TikTok into Supabase analytics tables. Generate weekly insight reports identifying top-performing hooks, platforms, and content pillars.
---

# Shortform Analysis

Ingest engagement data. Find patterns. Recommend what to make next week.

---

## Mode 1 — CSV Import

### Input

User provides a CSV export from Instagram or TikTok. Accept via:
- Pasted CSV text in the conversation
- File path to a CSV on disk

### Expected CSV Format

**Instagram (Insights export):**
```csv
Post,Date,Reach,Impressions,Likes,Comments,Saves,Shares
"[caption preview]",2026-04-15,12500,18200,342,28,89,45
```

**TikTok (Analytics export):**
```csv
Video,Date,Views,Likes,Comments,Shares,Average Watch Time,Completion Rate
"[caption preview]",2026-04-15,45000,1200,85,320,12.4s,42%
```

If the CSV format doesn't match exactly, parse intelligently — map columns by name, not position. Common variants:
- "Saves" may be "Bookmarks"
- "Shares" may be "Sends" or "Reposts"
- Date formats may vary (YYYY-MM-DD, MM/DD/YYYY, DD/MM/YYYY)

### Parse and Insert

For each row, match to an existing `content_posts` record by title/caption similarity and date. If no match, create a new record.

```sql
UPDATE content_posts
SET views = [views], likes = [likes], comments = [comments],
    saves = [saves], shares = [shares], posted_at = [date]
WHERE id = [matched_post_id];
```

If creating new (untracked post):
```sql
INSERT INTO content_posts (title, platform, posted_at, views, likes, comments, saves, shares, status)
VALUES ([caption_preview], [platform], [date], [views], [likes], [comments], [saves], [shares], 'published');
```

Report: "[X] posts updated, [Y] new posts created, [Z] unmatched rows"

---

## Mode 2 — Weekly Analysis

Run this after importing fresh data, or on demand.

### Step 1 — Pull Data

```sql
SELECT * FROM content_posts
WHERE posted_at >= NOW() - INTERVAL '7 days'
AND status = 'published'
ORDER BY posted_at DESC;
```

### Step 2 — Calculate Metrics

For each post, calculate engagement rate:
```
engagement_rate = (likes + comments + saves + shares) / views * 100
```

### Step 3 — Analyse Patterns

**By Hook Type:**
```sql
SELECT hook_type, COUNT(*) as uses, AVG(engagement_rate) as avg_engagement
FROM content_posts
WHERE posted_at >= NOW() - INTERVAL '30 days'
GROUP BY hook_type
ORDER BY avg_engagement DESC;
```

**By Platform:**
```sql
SELECT platform, COUNT(*) as posts, AVG(engagement_rate) as avg_engagement, SUM(views) as total_views
FROM content_posts
WHERE posted_at >= NOW() - INTERVAL '7 days'
GROUP BY platform
ORDER BY avg_engagement DESC;
```

**By Content Pillar:**
```sql
SELECT content_pillar, COUNT(*) as posts, AVG(engagement_rate) as avg_engagement
FROM content_posts
WHERE posted_at >= NOW() - INTERVAL '30 days'
GROUP BY content_pillar
ORDER BY avg_engagement DESC;
```

### Step 4 — Update Performance Tables

```sql
-- Update hook_performance
INSERT INTO hook_performance (hook_template, uses_count, avg_engagement_rate, best_platform)
VALUES ([hook_type], [count], [avg_rate], [best_platform])
ON CONFLICT (hook_template)
DO UPDATE SET uses_count = EXCLUDED.uses_count,
             avg_engagement_rate = EXCLUDED.avg_engagement_rate,
             best_platform = EXCLUDED.best_platform;

-- Update content_pillars
INSERT INTO content_pillars (pillar_name, post_count, avg_engagement_rate, last_updated)
VALUES ([pillar], [count], [avg_rate], NOW())
ON CONFLICT (pillar_name)
DO UPDATE SET post_count = EXCLUDED.post_count,
             avg_engagement_rate = EXCLUDED.avg_engagement_rate,
             last_updated = NOW();
```

### Step 5 — Generate Weekly Insight Report

```markdown
# Weekly Content Insights — YYYY-MM-DD

## Performance Summary
- Posts published: [X]
- Total views: [X]
- Average engagement rate: [X]%
- Best performing post: "[title]" — [views] views, [engagement_rate]%

## Top Hook Types (30-day rolling)
1. [Hook type] — [avg engagement]% ([uses] posts)
2. [Hook type] — [avg engagement]% ([uses] posts)
3. [Hook type] — [avg engagement]% ([uses] posts)

## Top Platforms
1. [Platform] — [avg engagement]% avg, [total views] views
2. [Platform] — [avg engagement]% avg, [total views] views

## Top Content Pillars
1. [Pillar] — [avg engagement]% ([posts] posts)
2. [Pillar] — [avg engagement]% ([posts] posts)

## Underperformers
- [Hook type/pillar] — [avg engagement]% (below average). Consider: [drop it / change angle / test different platform]

## 3 Recommendations for Next Week
1. [Specific recommendation with reasoning]
2. [Specific recommendation with reasoning]
3. [Specific recommendation with reasoning]
```

### Step 6 — Save Weekly Insight

```sql
INSERT INTO weekly_insights (week_starting, top_hook, top_pillar, top_platform, recommendations, created_at)
VALUES ([monday_date], [top_hook], [top_pillar], [top_platform], [recommendations_json], NOW());
```

Save the report to: `content-engine/reports/weekly-YYYY-MM-DD.md`

---

## Data Layer Notes

Reads from: `content_posts` (Supabase)
Writes to: `content_posts`, `hook_performance`, `content_pillars`, `weekly_insights` (Supabase)
