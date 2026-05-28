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

## Communication rules (non-negotiable)
- **No glazing.** Never compliment Matt's work, ideas, or decisions. Flattery is noise. Intent, efficiency, and first-time correctness are the only metrics that matter. If something is wrong or suboptimal, say so directly.
- **Intent interview before execution.** If a request is broad, ambiguous, or has multiple valid interpretations, stop and ask the minimum number of targeted questions to lock down intent before writing a single line. Do not guess, do not pick the most likely interpretation and proceed, do not produce a hedged multi-option response. Ask, wait, then act. Triggers: vague scope ("clean this up", "improve X"), unclear target (no specific file/feature named), multiple equally valid implementation paths, or any request where guessing wrong means rework.
- **Gate check before marking complete.** Before updating any plan, marking a phase APPROVED, or declaring work done — list every gate (build, previews, screenshots, DB migration, tests) with PASS/FAIL/SKIPPED. If any gate is not PASS, do not mark complete. Report what's outstanding and ask how to proceed.
- **Pre-flight before autonomous runs.** Before any multi-step autonomous task (release build, content pipeline, DB migration, multi-phase feature) — verify: correct project directory, CLAUDE.md in scope, Supabase SDK version, relevant API keys in env. Output a one-line summary, then proceed.

## Hard stops
- Always make targeted edits to existing files unless a full rewrite is explicitly needed or the file is being created for the first time. Never replace an entire file just to change a few lines.
- Never reference deleted, renamed, or obsolete files
- Never invent new Supabase tables, columns, relations, or backend workflows unless explicitly approved
- Never rename existing models, files, DB columns, or asset names unless explicitly approved
- Never assume helper methods or properties exist, state assumptions clearly first if needed
- Prefer the simplest stable implementation over clever or over-engineered solutions
- When fixing a bug, confirm the actual root cause before writing any code. Run /diagnose first. Never stack speculative fixes.

## Scope and read-only rules
- When asked to 'report', 'audit', 'observe', or 'read', do NOT make any code changes. Produce observations and summaries only. If a fix seems beneficial, propose it and wait for explicit approval.
- 'Report only, no edits' means Read/Grep/Bash(ls/cat/find) only — no Edit, Write, or Bash commands that modify files.
- When given a numbered task list, complete each task in order and stop. Do not add unrequested follow-on tasks.
- When creating plain-text config files (.gitignore, .env, .zshenv, etc.), use bash printf/heredoc rather than the Write tool to avoid markdown formatting artifacts. Verify contents with `cat` after creation.

## SwiftUI rules
See `.claude/rules/swiftui.md` — loads automatically when editing .swift files (includes app architecture, observable patterns, UI rules, auth, analytics).

## File structure rules
- New feature view models go in feature folders under `OnTrack/ViewModels/<Feature>/`
- New shared views go in `OnTrack/Views/Shared/`
- Prefer nesting small V1 helper models/enums/types inside the related file before creating new standalone files
- Do not create extra files unless they clearly improve maintainability

## Workflow rules
- Start Claude Code from:
  `cd ~/Desktop/OnTrack && claude --dangerously-skip-permissions`
- To work inside the Obsidian vault: `cd ~/Brain && claude --dangerously-skip-permissions`
- Before any multi-file edit, state the 5-line plan: files to touch, exact symbols, existing conflicts noticed, build/test command, one risk. Wait for my OK. (For complex work, use `/ultraplan` instead.)
- Before any Netlify deploy, check current deployment status first. Do not redeploy identical changes out of uncertainty.
- At the end of a Claude Code session, remind Matt to run `/insights`
- After any UI file edit: run `/capture` on the affected view's `#Preview` before committing — compile alone is not sufficient for design work.

## Subagent fan-out
For 4+ independent file edits, delegate to parallel subagents via the Task tool. Do NOT fan out when edits depend on each other sequentially. /ultraplan must list which subagents will be spawned before execution begins. Compress subagent prompts to the single file being edited plus a 100-word context summary — never pass the full project tree.

## Supabase keys & patterns
See `.claude/rules/supabase.md` — loads automatically when editing .swift and .sql files.

## Related docs
- App/build status: `PROJECT_STATUS.md`
- Schema and DB rules: `SCHEMA_RULES.md`
- RLS safety rules (read before ANY policy or UUID change): `SKILL_ontrack_rls_safety.md`

## Installed Claude Code plugins
- `/gsd:quick "task"` for small tasks, `/ultraplan` for large features. Run `/insights` at end of every session.

## Skill invocation rules
- `/advisor` is for debugging failing code or error triage ONLY. Do not invoke it for design, planning, or non-debugging tasks — it wastes context.
- `/ultraplan` before new features, significant refactors, or multi-file architectural changes. Not for bug fixes or single-file edits.

## Build and call-site rules
- Stay in ~/Desktop/OnTrack when starting — never start from ~ or a different directory
- If a slash command fails, report it immediately instead of spending the session trying workarounds

## Session end auto-log
At session end: (1) update `~/Brain/02-projects/ontrack/DAILY_STATUS.md` (auto-generated daily status dashboard — refresh the relevant sections, do NOT append numbered `## Session NN` entries); (2) write 5-line summary to `~/Desktop/OnTrack/OnTrack/.claude/logs/session-YYYYMMDD-HHMM.md`.

## MCP Servers
- Playwright MCP is the active browser automation tool. Do NOT attempt to use chrome-local-mcp or claude-in-chrome — deprecated, will not connect.
- If an MCP server fails to load after 2 attempts, stop and tell the user immediately.
- MCP server debugging has a 5-minute timebox. Pivot to alternative approach if not resolved.

## App Store Connect API
- Key ID: 9SJ6J5WR4U
- Issuer ID: 5b0f9937-7671-4ee9-a874-3097a137c780
- Key path: ~/.appstoreconnect/private_keys/AuthKey_9SJ6J5WR4U.p8

## Content pipeline rules
See `.claude/rules/content-pipeline.md` — loads automatically when editing scripts or website files.

## Diagnosis Before Fixing
- For bugs involving data not appearing: verify the component rendering path and data fetch BEFORE attempting fixes
- Confirm stated premises by reading the code first — never act on assumptions
- State root cause hypothesis + evidence before any code edit
