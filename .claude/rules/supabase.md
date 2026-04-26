---

## paths: \["**/\*.swift", "**/\*.sql"\]

## Important keys and patterns

- Check-in completion key: `checkin_completed_date`
- HealthKit last fetch key: `healthkit_last_fetch_date`
- Onboarding seen key pattern: `onboarding_seen_<screen>`
- Button tooltip seen key pattern: `tooltip_seen_<id>`
- Biometric auth enabled key: `biometric_auth_enabled`
- Biometric prompt shown key: `biometric_prompt_shown` (once-per-device gate)
- For Supabase DELETEs under RLS, include all policy-relevant columns in the filter
- Use typed Supabase decoding with `.execute().value`
- When switching from `.from()` to `.rpc()`, always use a lightweight decode struct (e.g. `struct GroupLookup: Decodable { let id: UUID; let name: String }`) — never decode RPC results directly into full models like `AppGroup` or `Friendship` which have non-optional fields that may be missing
- Before reverting an RPC back to a direct `.from()` query, check whether RLS will block non-member access — if yes, the RPC is required and the decode struct needs fixing, not the approach
- Use `upsert` with `onConflict:` where needed
- Always use `created_by` (NOT `user_id`) for habits queries
- Chain `.eq()` before `.select()`, not after
