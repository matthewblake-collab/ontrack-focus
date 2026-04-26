-- Content Engine — Supabase Migration
-- Run via Supabase SQL Editor or MCP execute_sql
-- Tables: 2 pipeline + 4 analytics = 6 total

---------------------------------------------------
-- PIPELINE TABLES
---------------------------------------------------

-- Ideas researched from Reddit, X, App Store, newsletters
CREATE TABLE IF NOT EXISTS content_ideas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  source_url TEXT,
  source_type TEXT, -- 'reddit', 'twitter', 'app_store', 'newsletter', 'competitor_gap'
  trending_reason TEXT,
  ontrack_angle TEXT,
  pillar TEXT, -- 'habit_science', 'fitness_tips', 'feature_demo', 'user_wins', 'app_comparison', 'why_people_fail'
  best_platform TEXT, -- 'instagram', 'tiktok', 'linkedin', 'twitter', 'threads'
  suggested_hook TEXT,
  audience_tier TEXT, -- 'macro', 'micro', 'both'
  research_score INT, -- 1-25 composite score
  status TEXT NOT NULL DEFAULT 'researched', -- 'researched' → 'ideated'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scripts and filming cards generated from ideas
CREATE TABLE IF NOT EXISTS content_scripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idea_id UUID REFERENCES content_ideas(id) ON DELETE SET NULL,
  archetype TEXT, -- from viral-content-patterns.md: 'impossible_demo', 'myth_bust', etc.
  format_type TEXT, -- 'talking_head', 'screen_record', 'text_overlay', 'carousel', 'mixed'
  hook_angle TEXT,
  hook_options JSONB, -- array of 6 hook strings
  chosen_hook TEXT,
  target_audience TEXT, -- 'macro', 'micro', 'both'
  thesis TEXT,
  best_platform TEXT,
  production_time TEXT, -- '5 min', '15 min', '30 min'
  filming_card TEXT, -- full markdown filming card
  voice_id TEXT, -- ElevenLabs voice_id used for TTS (rotation: Hans→Jordan→Dave→Charlotte→Emma→Hannah)
  voiceover_path TEXT, -- absolute path to generated .mp3
  video_path TEXT, -- absolute path to rendered Remotion .mp4
  status TEXT NOT NULL DEFAULT 'ideated', -- 'ideated' → 'scripted' → 'posted'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

---------------------------------------------------
-- ANALYTICS TABLES
---------------------------------------------------

-- Published posts with engagement metrics
CREATE TABLE IF NOT EXISTS content_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  script_id UUID REFERENCES content_scripts(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  platform TEXT NOT NULL, -- 'instagram', 'tiktok', 'linkedin', 'twitter', 'threads'
  hook_type TEXT, -- archetype used
  content_pillar TEXT,
  caption TEXT,
  hashtags TEXT,
  posted_at TIMESTAMPTZ,
  views INT DEFAULT 0,
  likes INT DEFAULT 0,
  comments INT DEFAULT 0,
  saves INT DEFAULT 0,
  shares INT DEFAULT 0,
  engagement_rate FLOAT GENERATED ALWAYS AS (
    CASE WHEN views > 0 THEN (likes + comments + saves + shares)::FLOAT / views * 100
    ELSE 0 END
  ) STORED,
  status TEXT NOT NULL DEFAULT 'ready', -- 'ready' → 'published'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregate hook template performance
CREATE TABLE IF NOT EXISTS hook_performance (
  hook_template TEXT PRIMARY KEY,
  uses_count INT DEFAULT 0,
  avg_engagement_rate FLOAT DEFAULT 0,
  best_platform TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregate content pillar performance
CREATE TABLE IF NOT EXISTS content_pillars (
  pillar_name TEXT PRIMARY KEY,
  post_count INT DEFAULT 0,
  avg_engagement_rate FLOAT DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Weekly insight snapshots
CREATE TABLE IF NOT EXISTS weekly_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_starting DATE NOT NULL,
  top_hook TEXT,
  top_pillar TEXT,
  top_platform TEXT,
  total_posts INT DEFAULT 0,
  total_views INT DEFAULT 0,
  avg_engagement_rate FLOAT DEFAULT 0,
  recommendations JSONB, -- array of recommendation strings
  report_markdown TEXT, -- full weekly report
  created_at TIMESTAMPTZ DEFAULT NOW()
);

---------------------------------------------------
-- INDEXES
---------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_content_ideas_status ON content_ideas(status);
CREATE INDEX IF NOT EXISTS idx_content_scripts_status ON content_scripts(status);
CREATE INDEX IF NOT EXISTS idx_content_posts_platform ON content_posts(platform);
CREATE INDEX IF NOT EXISTS idx_content_posts_posted_at ON content_posts(posted_at);
CREATE INDEX IF NOT EXISTS idx_content_posts_pillar ON content_posts(content_pillar);
CREATE INDEX IF NOT EXISTS idx_weekly_insights_week ON weekly_insights(week_starting);
