# SKILL: OnTrack RLS Safety

## When to use this skill
Read this skill before making ANY change to:
- Supabase RLS policies
- Supabase functions (SECURITY DEFINER or otherwise)
- Any query that joins across tables with their own RLS policies
- Any Swift code that passes UUIDs to Supabase `.eq()` or `.or()` filters

---

## The two most dangerous mistakes

### 1. Overly permissive SELECT policies cause data leakage
A policy like `invite_code IS NOT NULL` or `true` on a table means EVERY authenticated user can read EVERY row. This happened on `groups` in Session 37 — all users could see all groups.

**Rule:** SELECT policies must always scope to the current user. The safe patterns are:
```sql
-- Own rows only
auth.uid() = user_id

-- Rows in groups the user belongs to (use SECURITY DEFINER to avoid recursion)
id IN (SELECT get_my_group_ids())

-- Created by the user
auth.uid() = created_by
```

**Never use:**
```sql
-- DANGEROUS — exposes all rows to all users
invite_code IS NOT NULL
true
1 = 1
```

### 2. Self-referencing subqueries cause infinite recursion
A policy on `group_members` that queries `group_members` in its WHERE clause causes infinite recursion:
```sql
-- BROKEN — recursive
CREATE POLICY ... USING (
    group_id IN (SELECT group_id FROM group_members WHERE user_id = auth.uid())
);
```

**Fix:** Always use a SECURITY DEFINER function for any policy that needs to query its own table:
```sql
CREATE OR REPLACE FUNCTION get_my_group_ids()
RETURNS SETOF uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT group_id FROM group_members WHERE user_id = auth.uid();
$$;

CREATE POLICY ... USING (
    group_id IN (SELECT get_my_group_ids())
);
```

---

## Checklist before applying any RLS migration

1. **Audit the SELECT policy** — does it expose rows to users who shouldn't see them?
2. **Check for self-reference** — does the policy query the same table it's protecting?
3. **Test with a non-owner user** — would Jess (`e62c259f`) see Matt's private groups?
4. **Never patch null FK values with a real user ID** — delete orphaned rows instead
5. **After applying** — immediately verify with:
```sql
SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = '<table>';
```
6. **Force-close and reopen the app on a second test device** to confirm data isolation before moving on

---

## UUID case sensitivity
iOS `UUID.uuidString` returns UPPERCASE (e.g. `D4513D7C-...`).
Supabase PostgREST `.eq()` and `.or()` string filters are case-sensitive before UUID casting.

**Always lowercase UUIDs before passing to Supabase queries:**
```swift
let userId = appState.currentUser?.id.uuidString.lowercased() ?? ""
```

And in Swift filter comparisons:
```swift
pendingReceived = all.filter { $0.receiverId.lowercased() == userId }
```

---

## SECURITY DEFINER functions — when to use them
Use when:
- A policy needs to query the same table it's on (recursion prevention)
- A feature needs to work before the user is a member (e.g. invite code lookup, challenge invite check)

Always include:
```sql
SET search_path = public
```

SECURITY DEFINER functions in OnTrack:
- `get_my_group_ids()` — returns group IDs for current user, used in `group_members` and `groups` policies
- `get_group_by_invite_code(code)` — looks up a group by invite code without requiring membership
- `user_is_invited_to_challenge()` — checks challenge invites without recursion

---

## What went wrong in Session 37 (reference)
1. Changed `group_members_select` to allow members to see other members → triggered recursion
2. Fixed recursion with SECURITY DEFINER → correct
3. But existing `groups_select` had `invite_code IS NOT NULL` → every user saw every group
4. Patched null `created_by` with Matt's real user ID → pushed Matt's groups to all devices
5. Fix: dropped `invite_code IS NOT NULL`, used `get_my_group_ids()`, deleted orphaned rows
