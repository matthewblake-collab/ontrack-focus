# SESSION 44 START PROMPT
# OnTrack Focus — Content Engine Session
# Paste this entire block at the start of the new chat in Claude Code

---

App: OnTrack Focus. Project root: /Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack/
Stack: SwiftUI + MVVM + Supabase 2.41.1. Bundle ID: com.blakeMatt.OnTrack.
Status: Live on TestFlight. Solo developer. Approaching App Store submission.

Key rules:
- Targeted edits only — never replace full files to change a few lines
- Never mix @Observable and ObservableObject patterns
- Use AppGroup (not Group), AppSession (not Session)
- Never invent Supabase tables/columns without approval
- Dark UI with green accents — no white card patterns
- ELI5 explanations, step by step instructions always

---

## SESSION 44 MISSION: Content Engine

This session is about building and shipping the OnTrack Focus content system. NOT iOS code unless a bug blocks content.

### Read these files first (in this order):
1. /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/skills/SKILL_content_engine.md
2. /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/product-marketing-context.md
3. /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/social-content-plan.md
4. /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/content/month-2026-04.md

### What was done last session (43):
- ✅ Website deployed to ontrack-focus.com with new CRO copy (Hero, Mission, Download)
- ✅ Netlify CLI set up — future deploys: `cd ~/ontrack-website && npm run build && ~/.npm-global/bin/netlify deploy --prod --dir=dist`
- ✅ GitHub repo created: matthewblake-collab/ontrack-website (no auto-deploy yet — needs GitHub email verify)
- ✅ Netlify auth token saved in ~/.zshrc as NETLIFY_AUTH_TOKEN
- ✅ Founder story Reel rendered: ~/Desktop/OnTrack-Reel/out/founder-story-reel.mp4 (2.2MB, 1080x1920, 30s)
- ✅ Session card tap bug fixed in DailyActionsView.swift — built successfully
- ✅ backround_13 pushed as active background (cycleStartDate = March 30)
- ✅ 4-week content calendar written: .agents/content/month-2026-04.md
- ✅ Content engine skill created: .agents/skills/SKILL_content_engine.md

### Session 44 tasks (work through in order):

**TASK 1 — Post the Founder Story Reel (FIRST PRIORITY)**
Video is ready at ~/Desktop/OnTrack-Reel/out/founder-story-reel.mp4
Caption is in month-2026-04.md under "Mon Apr 14"
Use Computer Use to:
a) Open Instagram in Chrome → check if logged in as @ontrack_focus
b) If not logged in, ask Matt to log in first
c) Upload video + paste caption + post
d) Repeat natively on TikTok (ask Matt to do TikTok manually — no API)
e) Schedule on Facebook via Meta Business Suite

**TASK 2 — Build Remotion video: "Two Audiences" (Apr 16 post)**
Brief is in month-2026-04.md under "Wed Apr 16"
Project is at ~/Desktop/OnTrack-Reel
Create new composition TwoAudiences.tsx
Render to ~/Desktop/OnTrack-Reel/out/two-audiences-reel.mp4

**TASK 3 — Build Remotion video: "App Store Teaser" (May 5 post)**
Brief is in month-2026-04.md under "Mon May 5"
Create new composition AppStoreTeaser.tsx
Render to ~/Desktop/OnTrack-Reel/out/app-store-teaser.mp4

**TASK 4 — Schedule all ready posts via Meta Business Suite**
Use Computer Use to open business.facebook.com
Schedule each post from month-2026-04.md that has a complete caption
Set times per the scheduling checklist in the content calendar
Posts needing screen records are flagged — skip those, Matt records on device

**TASK 5 — Set up Buffer (if Meta Business Suite doesn't cover TikTok)**
Go to buffer.com → sign up free → connect Instagram + Facebook + TikTok
Queue posts from the content calendar

### Tools available in Claude Code:
- Remotion (globally installed) — video generation
- Corey Haines marketing skills (~/.agents/skills/) — content writing, CRO, copywriting
- Supabase MCP — DB queries if needed
- Computer Use (Claude in Chrome) — browser automation for posting/scheduling
- Apple Platform Skills — iOS if needed
- GSD + Superpowers — workflow enforcement
- Advisor Mode — escalate complex decisions to Opus after 2 failed attempts

### Access Matt needs to grant before starting:
- [ ] Log into Instagram @ontrack_focus in Chrome (Computer Use needs active session)
- [ ] Log into Meta Business Suite in Chrome (business.facebook.com)
- [ ] Confirm TikTok handle so we can set up Buffer correctly

### Important paths:
- Content calendar: /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/content/month-2026-04.md
- Content skill: /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/skills/SKILL_content_engine.md
- Marketing context: /Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/product-marketing-context.md
- Founder Reel (ready): ~/Desktop/OnTrack-Reel/out/founder-story-reel.mp4
- Remotion project: ~/Desktop/OnTrack-Reel/
- Website: ~/ontrack-website (deploy: npm run build && netlify deploy --prod --dir=dist)

### Run /ultraplan before starting Task 1 if anything is unclear.
### Run /insights at end of session.
### Remind Matt to run /dream to save context.
