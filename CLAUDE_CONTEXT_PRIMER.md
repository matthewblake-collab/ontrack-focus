# Claude Context Primer — Matt Blake
*Paste this at the start of any Claude conversation for instant full context.*
*Last updated: Session 49 — April 2026*

---

## Who I Am

Matt Blake. Solo founder and developer. Based in Port Macquarie, NSW, Australia. Former professional rugby league player. Ex-gym owner. I build OnTrack Focus — a SwiftUI iOS wellness and group accountability app. I work across Claude.ai (desktop/mobile), Claude Code in Terminal, and occasionally Chrome extension.

I prefer direct, minimal communication. ELI5 explanations when needed. I answer scoping questions briefly. I confirm successful builds with **"bs"**. I work through one task at a time.

---

## Active Projects

### OnTrack Focus (primary — everything)
- **What:** iOS wellness + group accountability app. Habits, supplements, sessions, check-ins, friends feed, knowledge library, AI insights.
- **Stack:** SwiftUI + MVVM + Supabase 2.41.1. iOS 17+.
- **Status:** Live on TestFlight v1.6. Approaching App Store launch.
- **Bundle ID:** `com.blakeMatt.OnTrack`
- **Supabase ref:** `wqkisslixduowewuaiae`
- **Project root:** `/Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack/`
- **Key files:** `CLAUDE.md` (rules), `PROJECT_STATUS.md` (status), `SCHEMA_RULES.md` (DB)
- **TestFlight:** `https://testflight.apple.com/join/q65zPgbv`
- **Website:** `ontrack-focus.com` (Netlify + Cloudflare DNS, React/Vite/Tailwind)
- **Support:** `matthewblake-collab.github.io/ontrack-support`
- **GitHub:** `matthewblake-collab`

### Marketing / Content
- 4-week content calendar written. Social handle: `@ontrack_focus`
- Remotion installed for animated video content (`~/Desktop/OnTrack-Reel`)
- `SKILL_content_engine.md` at `.agents/skills/` handles all content tasks
- upload-post.com API for Instagram + TikTok scheduling (free tier, 10 posts/month)

---

## App Architecture (critical rules)

- **Never mix** `@Observable` and `ObservableObject/@Published` patterns
- `@Observable`: GroupViewModel, SessionViewModel, AttendanceViewModel, FriendsViewModel
- `ObservableObject`: AppState, HabitViewModel, SupplementViewModel, AuthViewModel
- Model names: `AppGroup` (not Group), `AppSession` (not Session)
- Friend IDs are `String`, not `UUID` — never call `.uuidString` on them
- NavigationStack always outermost. Background always from `themeManager.currentBackgroundImage`
- Card bg: `Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)` with green accents
- Home tab = `DailyActionsView.swift` at `Views/Habits/` — there is no HomeView.swift
- Tabs: Home / Social / [FAB] / Wellbeing / Supps — Notifications is a sheet, not a tab

---

## Supabase Rules (critical)

- All UUIDs must be `.lowercased()` before queries — iOS returns uppercase, PostgREST fails silently
- `numeric` columns → use `float8`. Plain `date` columns → use `timestamptz`
- RLS-blocked DELETE returns success with 0 rows — always verify with row count
- `execute_sql` bypasses RLS — success there doesn't confirm app-level behaviour
- `habits` table uses `created_by` (not `user_id`). `habit_logs` uses `user_id`
- Edge Functions: deploy with `verify_jwt: false`, handle auth manually via `supabase.auth.getUser(jwt)`
- Never invent new tables/columns without explicit approval

---

## Claude Code Setup

**Workflow:**
- This chat (claude.ai): diagnosis, planning, prompt generation only — never writes files
- Claude Code in Terminal: all file writes and reads (`cd ~/Desktop/OnTrack && claude --auto-run`)
- Supabase MCP: all database operations
- One file at a time. Full file replacements for new files. Targeted edits only for changes.
- Build confirmation before proceeding to next file

**Installed tools:**
- GSD v1.30+ (spec-driven development, context engineering)
- Superpowers (brainstorm → plan → execute workflow)
- Claude Mem (session memory — use natural language, not `/dream` — GSD intercepts it)
- `/observe` skill at `~/.claude/commands/observe.md` (replaces memory observer sessions)
- SwiftUI Expert Skill (AvdLee)
- UI/UX Pro Max v2.0
- Apple Platform Skills (rshankras)
- Supabase MCP (HTTP, `~/.claude/settings.json`)
- Filesystem MCP (stdio, `~/.claude/settings.json`) — scoped to OnTrack project folders
- Playwright MCP (stdio)
- Magic MCP / 21st-dev UI generator
- UltraPlan (for complex multi-file features)
- Caveman
- PostToolUse hooks: JSON validation + Swift parse check after every Edit

**Key paths:**
- Obsidian vault: `~/.claude`
- OnTrack notes: `~/.claude/02-projects/ontrack/`
- SESSION_LOG.md: `~/.claude/02-projects/ontrack/SESSION_LOG.md`
- Content skills: `/Users/matthewblake/Desktop/OnTrack/OnTrack/.agents/skills/`
- Marketing site: `~/ontrack-website`

---

## Key People & Test Accounts

- **Jess** — test user on separate device for multi-user verification
- **lukecharet** — TestFlight tester for friend request flows
- **Matt's Supabase user ID:** `d4513d7c-0acc-4917-83b3-cb350a09a5f7`
- **Demo account:** `demo@ontrack.app` / `OnTrack2026!`

---

## Patterns & Learnings (what works)

**SwiftUI:**
- Prefer data-driven approaches over boolean flags — `@Published` fires multiple `onChange` callbacks causing timing issues
- `swipeActions` only work inside `List` — use context menus or manage sheets in `LazyVStack`
- DailyActionsView uses `ScrollView + LazyVStack`, NOT `List` — never reintroduce List
- Before any new SwiftUI pattern: ask Claude to evaluate known limitations first

**Workflow:**
- Always build after every file change before proceeding
- Separate planning sessions from implementation sessions — if a task needs UltraPlan, that's its own session
- Complex features (new screens, data model changes, multi-view): run `/ultraplan` first
- Batch 3-5 related bug fixes into one structured CC prompt with file paths front-loaded
- When CC hits 90% context on planning: save plan to file, start fresh implementation session

**Supabase:**
- Before any Supabase query: verify column names via MCP schema check, never assume
- RPC results: always use lightweight `struct TypeName: Decodable { let id: UUID; let name: String }`
- For security-sensitive user searches: use `SECURITY DEFINER` RPC

**MCP:**
- MCP config must go in `~/.claude/settings.json` — `claude mcp add` writes to `~/.claude.json` which CC ignores
- If MCP server fails after 2 attempts: stop and suggest session restart — don't keep debugging
- Knowledge Library was built in a separate chat — use CC file system search on struct names, not `conversation_search`

---

## What's NOT Working / Watch Out For

- GSD intercepts `/dream` — always phrase memory saves as natural language
- Playwright and chrome-local-mcp have caused multiple wasted sessions — validate connectivity before committing to a workflow
- App Store Connect API key caused persistent 401s — needs regeneration before next submission
- Sign in with Apple JWT expires ~October 2026 (Key ID: `R7NGBWJ2D4`, Team ID: `ZNSQCFUGV4`)

---

## Current Open Issues (Session 49)

**Bugs:**
1. APNs end-to-end delivery — needs device test with Jess
2. `feed_likes` table + `sessions.visibility` — confirm exist in prod DB before feed goes live
3. `joinSession` in FeedViewModel upserts with `status: String` but should use `attended: Bool`

**Next priorities:**
1. Check-in insights/trends screen
2. Onboarding flow improvements
3. App Store rejection response (5.1.1 Privacy)
4. Content schedule + upload-post.com pipeline

**Ideas backlog:**
- Knowledge Library: Recovery extension
- Knowledge Library: AI Synergy Linker (needs UltraPlan)
- Knowledge Library: Goal-driven search (needs UltraPlan)

---

## Non-Negotiable Prompt Rules (for Claude Code sessions)

1. **Every instruction for Matt must be in a single copiable text box.** Location label (e.g. "RUN IN Claude Code") must be INSIDE the box as the first line.
2. Targeted edits only — never replace full files to change a few lines
3. One file at a time. Confirm build before next file.
4. Never invent Supabase tables/columns without approval
5. Never mix @Observable and ObservableObject
6. ELI5 explanations always
7. "bs" = build succeeded, move on

---

## Founder Story (for content/marketing context)

Former professional rugby league player who never quite made it to the top — attributes it to lacking the right system, not ability. Worked 70-80 hour weeks away from family, let health deteriorate. Got back on track through competitive accountability with two mates. Owned a gym. Built OnTrack to replicate that experience for others. Brand tone: humble, direct, relatable — never preachy. Two audiences: people already grinding who need the right system, and people ready to make a real change. Social: `@ontrack_focus`.

---

*For full app status: read `PROJECT_STATUS.md` at `/Users/matthewblake/Desktop/OnTrack/OnTrack/PROJECT_STATUS.md`*
*For full DB schema: read `SCHEMA_RULES.md` at `/Users/matthewblake/Desktop/OnTrack/OnTrack/SCHEMA_RULES.md`*
*For permanent CC rules: read `CLAUDE.md` at `/Users/matthewblake/Desktop/OnTrack/OnTrack/CLAUDE.md`*
