---
paths: ["**/*"]
---

## Workflow Rules
- Before attempting edits, check if previous session changes are already applied. Read the target file first to avoid redundant edits that waste context.
- **State approach before implementing:** Before writing any code, state in one sentence: the pattern being used, any existing conflicts identified, and the risk. Wait for implicit or explicit OK. This catches wrong-approach errors before they cost iterations.
- **Verification before acting:** Before re-applying an edit, redeploy, or re-running a migration — check current state first. The work may already be done. Redundant redeploys and re-applied edits are a recurring waste pattern.
- **Sub-agent prompts under 500 chars:** When spawning Task agents, each prompt must ask exactly one question with an explicit output format. Spawn multiple narrow agents rather than one wide one to avoid prompt-too-long errors.
- **Context budget on long tasks:** For any task over 8 steps, front-load all blocking/critical work first and defer screenshot capture, doc updates, and polish until after code is committed. If approaching context limit, commit current work and explicitly report remaining items — never silently drop final steps.
- **iOS pre-flight before any Supabase query code:** Check Supabase Swift SDK version from Package.resolved before writing queries. API surface changes between versions — do not assume method signatures from memory.
