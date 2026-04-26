# CLAUDE.md

## Mission
Work on OnTrack Focus, a SwiftUI + MVVM iOS app with a Supabase backend for group scheduling, accountability, and wellness tracking.

App/TestFlight name: OnTrack Focus  
Bundle ID: com.blakeMatt.OnTrack

Project root:
`/Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack/`

## Known Pitfalls (never repeat these)
- Never invoke `/advisor` for design or architecture questions — only for active debugging
- Before any Netlify deploy, check if previous deploy is already live first — avoid redundant deploys
- Before any TestFlight/GitHub publishing work, pre-flight check: verify Team ID, API key, gh CLI auth, SSH keys exist

## Hard stops
- Always make targeted edits to existing files unless a full rewrite is explicitly needed or the file is being created for the first time. Never replace an entire file just to change a few lines.
- Never reference deleted, renamed, or obsolete files
- Never invent new Supabase tables, columns, relations, or backend workflows unless explicitly approved
- Never rename existing models, files, DB columns, or asset names unless explicitly approved
- Never assume helper methods or properties exist, state assumptions clearly first if needed
- Prefer the simplest stable implementation over clever or over-engineered solutions

## Output rules
- Full replacement files only
- Code must be ready to paste into Xcode
- Keep changes as small and safe as possible
- When changing one feature, check related models, views, view models, and Supabase mappings for downstream impact
- ELI5 explanations and step-by-step instructions are preferred

## Architecture
- SwiftUI + MVVM + Supabase
- Entry point: `OnTrackApp.swift`
- Root flow:
  1. `LaunchScreenView`
  2. `ContentView`
  3. `OnboardingView` if onboarding incomplete
  4. `MainTabView` if authenticated and onboarded

## SwiftUI rules
See `.claude/rules/swiftui.md` — loads automatically when editing .swift files.
Covers: observable patterns, naming, UI rules, onboarding/tooltip systems, key feature behaviours, auth, DailyActionsView rendering, app structure, crash reporting (Sentry), product analytics (PostHog), build and call-site rules.

## File structure rules
- New feature view models go in feature folders under `OnTrack/ViewModels/<Feature>/`
- New shared views go in `OnTrack/Views/Shared/`
- Prefer nesting small V1 helper models/enums/types inside the related file before creating new standalone files
- Do not create extra files unless they clearly improve maintainability

## Workflow rules
- Start Claude Code from:
  `cd ~/Desktop/OnTrack && claude --dangerously-skip-permissions`
- To work inside the Obsidian vault (for session logs, decisions, backlog): `cd ~/Brain && claude --dangerously-skip-permissions`
- At the start of major feature work, check Awesome Claude Code for any genuinely useful tools if relevant
- At the end of a Claude Code session, remind Matt to run `/insights`
- Do not commit secrets or hardcoded API keys
- Before any multi-file edit, state the 5-line plan: files to touch, exact symbols, existing conflicts noticed, build/test command, one risk. Wait for my OK. (For complex work, use `/ultraplan` instead.)
- Before any Netlify deploy, check current deployment status first. Do not redeploy identical changes out of uncertainty.

## Subagent fan-out
For 4+ independent file edits, delegate to parallel subagents via the Task tool. Do NOT fan out when edits depend on each other sequentially. /ultraplan must list which subagents will be spawned before execution begins. Compress subagent prompts to the single file being edited plus a 100-word context summary — never pass the full project tree.

## Obsidian vault
- Vault path: `~/.claude`
- OnTrack notes: `~/Brain/02-projects/ontrack/`
- File tree: `~/Brain/02-projects/ontrack/FILETREE.md` — read on demand

## Supabase keys & patterns
See `.claude/rules/supabase.md` — loads automatically when editing .swift and .sql files.
Covers: UserDefaults keys, RLS delete patterns, typed decoding, RPC vs direct query decisions, upsert patterns.

## Related docs
- Current app/build status: `PROJECT_STATUS.md`
- Current schema and DB rules: `SCHEMA_RULES.md`
- Old archive/reference file: `CLAUDE_OLD_ARCHIVE.md`
- Visual state cards (borders, lifecycle, completion): `SKILL_ontrack_visual_states.md` in OnTrack folder
- Daily card styling patterns: `SKILL_ontrack_daily_cards.md` in OnTrack folder
- RLS safety rules (read before ANY policy or UUID change): `SKILL_ontrack_rls_safety.md` in OnTrack folder
- Session end checklist and CC prompt: `SESSION_END_PROMPT.md` in OnTrack folder

## Installed Claude Code plugins
- **GSD** (Get Shit Done) — installed globally at `~/.claude/commands/`. Use `/gsd:quick "task"` for small tasks, `/gsd:new-project` for new features. Token-heavy — only use full workflow for large features.
- **Superpowers** — installed globally at `~/.claude/plugins/`. Triggers automatically when starting a task. Enforces brainstorm → plan → execute workflow. Low token overhead.
- **Claude Mem** — installed globally. Run `/insights` at end of every session to save context.
- **SwiftUI Expert Skill** — installed globally.
- **UI/UX Pro Max** — installed globally.
- **Apple Platform Skills** — installed globally via npx.
- **Playwright MCP** — installed via npx. Enables headless browser automation and web testing. Config in `~/.claude/settings.json` under `mcpServers`.

## Skill invocation rules
- `/advisor` is for debugging failing code or error triage ONLY. Do not invoke it for design, planning, or non-debugging tasks — it wastes context.
- `/ultraplan` before new features, significant refactors, or multi-file architectural changes. Not for bug fixes or single-file edits.

## Build and call-site rules
- Stay in ~/Desktop/OnTrack when starting — never start from ~ or a different directory
- If a slash command fails, report it immediately instead of spending the session trying workarounds

## Session end auto-log
At session end: (1) append to `~/Brain/02-projects/ontrack/SESSION_LOG.md` using format `## Session NN — DD Mon YYYY` / `### Fixed: [list]` / `### Built: [list]` / `### Open: [list]`; (2) write 5-line summary to `~/Desktop/OnTrack/OnTrack/.claude/logs/session-YYYYMMDD-HHMM.md`.

## Workflow Rules
- Before attempting edits, check if previous session changes are already applied. Read the target file first to avoid redundant edits that waste context.
- **State approach before implementing:** Before writing any code, state in one sentence: the pattern being used, any existing conflicts identified, and the risk. Wait for implicit or explicit OK. This catches wrong-approach errors before they cost iterations (41 wrong-approach occurrences across sessions).
- **Verification before acting:** Before re-applying an edit, redeploy, or re-running a migration — check current state first. The work may already be done. Redundant redeploys and re-applied edits are a recurring waste pattern.
- **Environment pre-check for autonomous runs:** Before any multi-step autonomous task (release build, content pipeline, DB migration), verify: brew exists, gh auth is valid, SSH key is registered, required API keys are in env. Flag any gaps immediately rather than discovering them mid-task.

## Configuration Files
- When editing JSON config files (settings.json, ExportOptions.plist), always validate JSON syntax after edits. Watch for trailing commas and incorrect field values.

## MCP Servers
- Playwright MCP is the active browser automation tool. Do NOT attempt to use chrome-local-mcp or claude-in-chrome — they are deprecated and will not connect.
- If an MCP server fails to load after 2 attempts, stop and tell the user immediately — do not spend the session debugging it.
- MCP server debugging has a 5-minute timebox. If an MCP server doesn't connect after 2 attempts, pivot to an alternative approach or skip that task entirely.

## App Store Connect API
- Key ID: 9SJ6J5WR4U
- Issuer ID: 5b0f9937-7671-4ee9-a874-3097a137c780
- Key path: ~/.appstoreconnect/private_keys/AuthKey_9SJ6J5WR4U.p8
- Use these for all xcodebuild -exportArchive and TestFlight upload commands

## Content pipeline rules
See `.claude/rules/content-pipeline.md` — loads automatically when editing scripts or website files.
Covers: Remotion rules, render output paths, Python compatibility, observer agent output format, React/Vite rules, Visual Docs auto-update.

## Toolkit
Living toolkit registry: ~/Brain/02-projects/ontrack/TOOLKIT.md — update this file whenever a new tool, plugin, MCP, or repo is added or removed.

## Deployment Verification
Before re-deploying any service, check whether previous changes are already live (read deployment logs or hit a health endpoint). Avoid redundant redeploys.

## Sandbox & Policy Awareness
- Git pushes to external repos and main branch pushes are often blocked by sandbox policy — check before attempting
- Post Bridge publishing requires active authorization; surface auth errors early
- If Homebrew/gh CLI/SSH keys are missing, flag the prerequisite gap before attempting publish operations

## Visual Docs Auto-Update
- After any implementation that changes pipeline architecture, services, or Jarvis, call `visual_docs_updater.update()` via `brain_updater` — this is already wired
- Item titles flowing through `pending_implementations.json` must be clean user-facing copy — they appear verbatim in HTML docs

## Git Push Policy
Git pushes to main and external repos may be blocked by sandbox policy. Always check policy-limits.json or ask the user to push manually rather than retrying.

## Slash Commands
Slash commands (/login, /logout, etc.) only work inside interactive Claude sessions, not from bash. When the user needs them, instruct them to run interactively rather than attempting via Bash tool.

## API Cost Awareness
Direct API calls (messages.create, claude()) use credits - flag token cost before proceeding. MCP calls (Supabase, PostHog, Gmail, Drive, Slack, Sentry) do NOT.

## Gmail Rules
- Google security alerts (no-reply@accounts.google.com): delete, skip report
- Anthropic billing alerts: flag as URGENT
- Promo/travel emails: archive, skip report

## Read-Only Tasks
When asked for a report, audit, analysis, or review — do NOT modify, refactor, or disable any code or services. Produce findings only. Ask explicit permission before making any edits.

## Python Compatibility
Target Python 3.9.6 for all Jarvis and routine scripts. Always add `from __future__ import annotations` when using PEP 604 union types. Avoid Python 3.10+ syntax in runtime code.

## File Writing
When creating .gitignore or other plain-text config files, always use `printf` or `cat <<EOF` via Bash — never the Write tool, which adds markdown formatting artifacts.
