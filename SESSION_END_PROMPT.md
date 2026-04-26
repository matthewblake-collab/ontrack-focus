# SESSION_END_PROMPT.md
# Copy and paste this entire block into Claude Code at the end of every session.
# Last updated: Session 37

---

## PASTE INTO CLAUDE CODE AT END OF EVERY SESSION:

```
Please do the following to close out this session:

1. Save session memory by running the claude-mem dream command as a natural language instruction — write a summary of everything completed this session to memory including all files changed, bugs fixed, and patterns learned

2. Update PROJECT_STATUS.md:
   - Update "Current state" paragraph to reflect what was built/fixed this session
   - Move completed items into the correct "Built and working" section
   - Remove resolved bugs from "Known bugs / open issues"
   - Update "Next priorities" to reflect what comes next

3. Update CLAUDE.md:
   - If any new files were created, add them to the File Tree section
   - If any new patterns or rules were established, add them to the relevant section
   - Update the "Last updated: Session X" line in the File Tree comment to the correct session number

4. Run /insights and show me the output

5. Confirm when all steps are done
```

## Why step 1 is phrased as natural language
GSD plugin intercepts `/dream` as a slash command. Phrasing it as a natural language instruction causes Claude Mem to handle it directly without GSD intercepting.

---

## What each step does

**`/dream`** — saves the full session context via Claude Mem plugin so the next session starts with full awareness of what was done. Must be phrased as natural language to CC because GSD plugin intercepts the slash command.

**PROJECT_STATUS.md** — the handover doc. Always reflects current true state of the app. The next session starter prompt is generated from this file.

**CLAUDE.md** — the permanent rules file. File tree, architecture rules, naming rules, patterns. Keeps CC from making mistakes on subsequent sessions.

**`/insights`** — Claude Code built-in command that surfaces patterns, repeated mistakes, and workflow improvements from the session. Paste output into chat for review.

---

## New items added this session (Session 37)

- After any RLS policy change: force-close and reopen app on a second test device before confirming the fix
- Always read SKILL_ontrack_rls_safety.md before any Supabase policy or UUID-related change
- UUID case: always lowercase before Supabase queries (`id.uuidString.lowercased()`)
- RPC decode: always use a lightweight struct, never a full model (e.g. AppGroup) which has non-optional fields
- Before reverting RPC to direct query: check if RLS blocks non-member access first
- /dream failing via GSD: flagged by /insights as top friction source — consider creating a custom CC skill for it
