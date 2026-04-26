# SKILL: OnTrack Content Engine
# Version: 1.0
# Purpose: Plan, write, generate, and schedule social content for OnTrack Focus across Instagram, TikTok, Facebook, website, and TestFlight testers.

## When to use this skill
- Planning weekly or monthly content
- Writing captions and hooks in Matt's voice
- Generating Remotion video assets
- Scheduling posts via Meta Business Suite
- Writing TestFlight release notes and tester updates
- Writing website copy updates
- Responding to new feature ships with content

## Always read first
Before any content task, read these two files:
1. `/Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/product-marketing-context.md` — product, founder story, tone of voice
2. `/Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/social-content-plan.md` — pillars, cadence, 10 ready posts, hashtag bank

## Content pillars (summary)
1. Accountability & Showing Up (30%) — emotional core, group accountability, streaks
2. Founder Story & Building in Public (25%) — Matt's rugby league story, working away, two mates, built OnTrack
3. Feature Drops & App Updates (20%) — every build is a content moment
4. Wellness & Consistency Education (15%) — value-first, habits, supplements, sleep
5. Community & Social Proof (10%) — tester wins, group milestones, streaks

## Matt's voice rules (non-negotiable)
- First person, direct, personal
- Humble and relatable — not a highlight reel
- Never preachy — stand beside the reader, not above them
- Motivating without being aggressive
- Real beats polished
- Two audiences: people already grinding who need the right system, and people ready to start
- Never say "the team" or "the app" — say "I" and "OnTrack"

## Platforms and formats
| Platform | Primary format | Repurpose from |
|----------|---------------|----------------|
| Instagram | Reels (30–60s), Stories, Carousel | Original |
| TikTok | Reels (no IG watermark, native upload) | Instagram |
| Facebook | Reels, text posts | Instagram |
| Website | Copy updates, blog posts | Content plan |
| TestFlight | Release notes, tester emails | Per-build notes |

## Remotion video generation
Project lives at: `~/Desktop/OnTrack-Reel`
Re-render command: `cd ~/Desktop/OnTrack-Reel && npx remotion render FounderReel out/founder-story-reel.mp4`
For new videos: create new composition in `~/Desktop/OnTrack-Reel/src/`
Style: Dark #0D141A bg, white text, green #1A8C6B accents, system-ui heavy, subtle grain, fade+drift animations

## Scheduling workflow
1. Generate all content assets (captions, videos, graphics)
2. Open Meta Business Suite via Computer Use → schedule Instagram + Facebook
3. TikTok: native upload only (no API auto-publish for personal accounts) → queue as reminder
4. Save all assets to `/Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/content/YYYY-MM-DD/`

## Per-build content workflow (run after every TestFlight build)
1. Read new features from build notes
2. Write "What Just Shipped" post using template in social-content-plan.md
3. Generate Remotion feature preview video if visual feature
4. Schedule post immediately
5. Update TestFlight tester notes
6. Flag any website copy that needs updating

## Monthly content planning workflow
1. Read product-marketing-context.md + social-content-plan.md
2. Check PROJECT_STATUS.md for upcoming features
3. Map 4 weeks × 5 posts = 20 posts across 5 pillars
4. Write all captions in advance
5. Flag which posts need Remotion videos vs screen records vs static
6. Save to `/Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/content/month-YYYY-MM.md`

## Advisor mode
If content strategy questions are complex or ambiguous, escalate to Opus after 2 attempts.
Trigger: run `claude --model claude-opus-4-5` for strategy decisions.
