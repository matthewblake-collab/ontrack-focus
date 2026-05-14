# Premium Dashboard — Session Handoff

**Branch:** `feat/premium-dashboard`
**Plan:** `~/Desktop/OnTrack/.ultraplan/plan.md`
**Started:** 2026-05-14

## Status

| F | Title | State | Commit |
|---|-------|-------|--------|
| 1 | DB schema migration + premium flip | ✅ done | `40b9b78` |
| 2 | iOS Protocol Setup | ✅ done | `21c0f1b` |
| 3 | Web dashboard scaffold | ⚠️ code done, Netlify deploy pending | latest |
| 4 | Check-in sync + Overview | pending | |
| 5 | Supplement adherence | pending | |
| 6 | Bloodwork + TRT migration | pending | |
| 7 | Workouts + PBs + Body Metrics | pending | |
| 8 | Unified Journal | pending | |
| 9 | Customisable layout | pending | |
| 10 | Partner Offers page | pending | |
| 11 | iOS dashboard entry + Edge Function | pending | |
| 12 | Realtime audit + SYNC_TEST.md | pending | |

## Done in this session

### F1 — DB migration (commit `40b9b78`)
- `supabase/migrations/20260514120000_premium_dashboard.sql` — 8 new tables w/ RLS, idempotent indexes, 3 seed partners + 3 discount codes
- `20260514120001_set_premium_testflight_users.sql` — Matt premium attempt (missed)
- `20260514120002_premium_via_foundation_match.sql` — found Matt by pattern match
- **Matt's UUID:** `d4513d7c-0acc-4917-83b3-cb350a09a5f7` (`matthew.blake@outlook.com.au`) — `is_premium=true` ✓
- **Luke:** NOT FOUND in foundation members. Need his email/UUID to flip.

### F2 — iOS Protocol Setup (commit `21c0f1b`)
- 5 new files: `Models/UserProtocol.swift`, `Models/ProtocolConfig.swift`, `ViewModels/Profile/ProtocolViewModel.swift`, `Views/Profile/ProtocolSetupView.swift`, `Views/Profile/ProtocolDetailFormView.swift`
- 2 modifications: `Models/Profile.swift` (+isPremium/premiumSince), `Views/Shared/ProfileView.swift` (+protocol section)
- Renamed `ProtocolPhase` → `ProtocolPhaseTemplate` to avoid collision with `KnowledgeItem.ProtocolPhase`
- `xcodebuild -scheme OnTrack`: BUILD SUCCEEDED
- **UAT pending:** simulator test of save flow + Supabase row inspection

### F3 — Web dashboard scaffold (latest commit)
- `ontrack-dashboard/` Next.js 14 App Router project (monorepo subdir of `~/Desktop/OnTrack/OnTrack/`)
- Auth via `@supabase/ssr` (server + browser clients, cookies pattern)
- Middleware: redirect unauthenticated `/dashboard/*` → `/dashboard/login`
- Server-side premium gate in `app/dashboard/(protected)/layout.tsx` → `UpgradePrompt` if `is_premium != true`
- 8 nav routes scaffolded (overview, bloodwork, biometrics, supplements, workouts, journal, offers, settings)
- Theme tokens in `globals.css` + `tailwind.config.ts`
- `npm run build`: PASS, 15 routes
- **BLOCKED:** Netlify deploy. `netlify login` needs interactive browser auth.

## Blockers (user action required)

1. **Netlify deploy** (F3 final gate):
   ```bash
   cd ~/Desktop/OnTrack/OnTrack/ontrack-dashboard
   netlify login                    # opens browser
   netlify init                     # connect/create site (set base=ontrack-dashboard)
   netlify env:set NEXT_PUBLIC_SUPABASE_URL https://wqkisslixduowewuaiae.supabase.co
   netlify env:set NEXT_PUBLIC_SUPABASE_ANON_KEY sb_publishable_D3oWivPWXCKwPs6LHoLzvw_m-8MlWpS
   netlify deploy --build --prod
   ```
   Take the resulting `https://<site>.netlify.app` URL — needed in F11 for iOS SFSafari magic-link target.

2. **Luke's premium flag:** Provide Luke's email or UUID:
   ```sql
   update profiles set is_premium=true, premium_since=now()
     where id = (select id from auth.users where lower(email)=lower('<luke-email>'));
   ```

3. **F2 simulator UAT:** Run OnTrack in simulator → Profile tab → tap protocol card → pick TRT → save. Confirm row in Supabase `user_protocols`.

## Resume instructions (next session)

```
cd ~/Desktop/OnTrack/OnTrack
git checkout feat/premium-dashboard
cat PREMIUM_DASHBOARD_HANDOFF.md          # this file
cat .ultraplan/plan.md                    # full 12-feature plan (one level up)
```

The ultraplan plan file is at `~/Desktop/OnTrack/.ultraplan/plan.md` (parent dir, **not** the iOS repo).

### F4 starting point (Overview + Realtime)
- Pull `daily_checkins` (last 30 rows by `checkin_date desc`) in server component at `app/dashboard/(protected)/overview/page.tsx`
- Replace the placeholder card with: `<SparklinesWidget />`, `<TodayCard />`, `<ThirtyDayChart />`, `<CorrelationStrip />`
- New components in `app/dashboard/(protected)/_components/` (matches existing `SideNav`/`ProtocolBadge` pattern)
- Realtime hook: `app/dashboard/_lib/useRealtime.ts` wrapping `supabase.channel('checkins-' + userId).on('postgres_changes', {event:'INSERT', schema:'public', table:'daily_checkins', filter: \`user_id=eq.${userId}\`}, ...)`
- `daily_checkins.checkin_date` is TEXT (`yyyy-MM-dd`) — parse via `new Date(row.checkin_date + 'T00:00:00Z')`
- Correlation: Pearson `r` between `sleep[t]` and `energy[t+1]`, `wellbeing[t]` vs `mood[t]`, etc. Show the highest |r| pair.

### Files referenced by remaining features
See `~/Desktop/OnTrack/.ultraplan/plan.md` — each feature's section lists exact file paths to create.

### Schema gotchas already discovered
- `daily_checkins.checkin_date` is TEXT (yyyy-MM-dd)
- `personal_bests.logged_at` is TEXT
- `profiles` owner column is `id` (= auth.users.id), not `user_id`
- iOS uses synced Xcode groups — dropping files in the right dir auto-includes (no pbxproj edits needed)
- iOS uses BOTH `@Observable` (newer VMs) and `ObservableObject + @Published` (older VMs). For new VMs prefer `@Observable` to match `ProgressViewModel`, `ProtocolViewModel`, `ReadinessViewModel`.
- iOS theme is in `Core/ThemeManager.swift` (`AppTheme` enum). Web theme is separate (CSS vars).
- iOS Supabase client singleton: `let supabase = SupabaseClient(...)` in `Core/SupabaseClient.swift:4`. Use that everywhere, do NOT instantiate new clients.

### Stack-level decisions already made
- Web project lives at `~/Desktop/OnTrack/OnTrack/ontrack-dashboard/` (monorepo)
- All TRT data migration scripts will live in `ontrack-dashboard/scripts/` and use TWO Supabase clients (read from `aboedqgvxylyyocawqxo`, write to `wqkisslixduowewuaiae`)
- Magic-link entry (F11) via Edge Function `supabase/functions/generate-dashboard-magic-link/`
- Idempotency indexes already created in F1: `blood_markers(user_id, marker, collected_at)` and `health_journal(user_id, entry_date, week_number, md5(body))`

### Other repo state notes
- `main` branch has many untracked migration files (April-May, "applied via MCP" placeholders). NOT my changes — leave alone.
- `.claude/worktrees/` and `.ultraplan-knowledge/` are untracked — also leave alone.
