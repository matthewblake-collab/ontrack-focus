# PROJECT_STATUS.md

## App
OnTrack Focus — live on App Store (v1.5.2, build 6)

## Stack
- SwiftUI + MVVM + Supabase
- iOS 17+, Xcode, Claude Code

## Current state
App is live on App Store (v1.5.2, build 6). Session 47 added supplement start date enforcement, invite-friends flow in GroupDetailView, bell badge for pending notifications, group list auto-refresh on invite accept, and various supplement detail/editing improvements.

---

## Built and working

### Auth & Onboarding
- Auth flow (email + Sign in with Apple + Face ID biometric re-login)
- 4-page onboarding with screen-level overlays

### Groups
- Create, join, delete, chat, stats, leaderboard, coach dashboard
- Group member session streaks
- Group chat read receipts
- GroupStatusCardView with real-time per-group check-in status (GroupStatusVM, @Observable)
- Group status cards shown on Home (today only) and Groups list
- Group join via invite code uses SECURITY DEFINER RPC (bypasses RLS for non-members)
- groups SELECT policy tightened — users only see groups they created or are a member of
- Bell badge in GroupListView shows red dot when pending friend requests or group invites exist (S47)
- Group list auto-refreshes when a group invite is accepted via NC `.groupMembershipChanged` (S47)
- Invite friends to group directly from GroupDetailView via InviteMembersSheet (S47)

### Sessions
- Recurring sessions, RSVP, availability, attendance, comments
- Session types with filter chips and DB persistence
- Edit sessions after creation (EditSessionView + SessionViewModel.updateSession)
- Session title and location autocomplete from past sessions

### Habits
- Personal + group habits, streaks, archive, privacy, friend invites
- Streak freeze (once per week per habit)
- Habit type picker, linking to groups
- Visibility prompt on save (default OFF, alert asks user on save)
- Daily Actions empty state has "Add Habit" CTA button

### Supplements
- **Tab structure: Protocol / My Stack / Stock** (Today tab removed — S45)
- Protocol = active supplements driving DailyActionsView (in_protocol = true)
- My Stack = full library of owned supplements
- Stock = quantity tracking
- Manage Protocol sheet — add from stack / remove from protocol in one place
- `in_protocol` boolean column on supplements table (migrated S45 — all existing active supps set to true)
- Stock tracking, logging, share via codes, vial calculator
- Supplement name autocomplete from `supplement_types`
- Edit supplements from Today, My Stack, and Stock tabs
- Green completion borders on supplement rows
- Stack Complete celebration card with particles
- Supplement reminders respect days_of_week schedule
- HealthKit auto-fetch on app launch (MainTabView .task — added S45)
- Start date respected — supplements with future `start_date` excluded from daily list (S47)
- Share stack encodes `dose_amount` + `dose_units` (replaces legacy `dose` string) (S47)
- SupplementDetailView shows dose (amount+units), stock quantity, schedule, notes, start date (S47)
- "Calculate dose" button in EditSupplementView opens SupplementDoseCalculatorView (S47)
- New supplements default to off-protocol — user must explicitly opt in (S47)
- Supplement reminder fire times corrected (morning 7:30, pre-workout 8:00, etc.) and trigger uses exact fire date to correctly handle today-vs-tomorrow (S47)

### Mental Health / Wellbeing
- Daily check-in with sleep, energy, wellbeing, mood, stress
- HealthKit prefill for daily check-in
- HealthKit auto-refreshes on app launch (no manual refresh needed — S45)
- Wellbeing trends with Swift Charts (carousel: Wellbeing, Sessions, Habits, Supplements)
- Wellbeing trend card heading fits on one line (S45 fix)
- AI wellness insights
- Breathwork coach
- Cycle tracker
- Progress sheet (personal stats)

### Friends tab (FriendsTabView — tab 5)
- Three sub-tabs: Feed / Friends / Requests
- Friends list with search (by username and friend code), send/accept/decline/remove
- Name search scoped to mutual connections only (privacy — not a global user directory)
- Friend code QR sheet
- Feed sub-tab: today's sessions from friends, group streaks, heart likes, join public sessions
- Notifications (bell) accessible as a sheet from every tab's header button
- NotificationsView shows pending friend requests, habit invites, group invites
- Friend requests dedup via UI status states
- Search results filter out current user — self never appears in results (S47)
- QR scanner in Friends tab (S68)
- UUID case-insensitive comparison fixes across friends and groups (S68/S69)

### Daily Actions (Home tab)
- Priority card with progress tracking and scroll-to-first-incomplete
- Celebration overlay on full daily completion
- Date browser (–3/+3 day scroll)
- Haptic feedback on completion buttons
- Empty state "Add Habit" CTA button (S45)
- Supplements shown driven by `protocolSupplements` (in_protocol = true only)

### Other
- Push permission dialog flow
- APNs token saved to DB
- Background image cycling via ThemeManager
- Button-level tooltips: Groups +, DailyActions +, MentalHealth check-in, supplement timing
- Reset My Stats in Settings
- Playwright MCP installed and connected (Claude Code — S45)
- 21st-dev broken connector removed (S45)

---

## Important patterns
- `DailyCheckInViewModel` is lifted in callers and passed into `DailyCheckInView`
- Check-in state uses `checkin_completed_date`
- HealthKit fetch tracking uses `healthkit_last_fetch_date`
- Background images always use `themeManager.currentBackgroundImage`
- Asset names intentionally use `backround_X`
- Profile is a sheet from a header button, not a tab
- Friends is tab 5 (FriendsTabView) — no longer a sheet
- Notifications is a sheet via bell button in each tab header — not a tab
- FeedViewModel is `@Observable`, instantiated with `@State`
- Supplements: `todaysSupplements` filters from `protocolSupplements` (not all supplements)
- `in_protocol = true` is what drives both Protocol tab and DailyActionsView supplements

---

## Known bugs / open issues

### Medium priority
1. APNs end-to-end delivery not yet confirmed — needs device test
2. `feed_likes` table and `sessions.visibility` — confirm exist in production DB before feed goes live
3. `attendance` table `joinSession` bug in FeedViewModel — upserts with `status: String` but should use `attended: Bool`

### Low priority
4. Improve onboarding clarity and retention over time
5. HealthKit auto-fetch on launch needs real device confirmation (simulator only so far)

---

## Next priorities (short-term)
1. Check-in insights/trends screen
2. Onboarding flow improvements
3. Cycling backgrounds refinement
4. Confirm APNs end-to-end delivery

## Medium-term
5. AI wellness insights expansion
6. Coach role — admin sees team wellness
7. Apple Health enhancements (extended cards, calorie balance)
8. Smart notifications

## Ideas backlog (Session 49)
- Knowledge Library: Recovery extension — add recovery pillar (sleep protocols, cold/heat therapy, mobility, active recovery) using same compound format
- Knowledge Library: AI Supplement Synergy Linker — inside compound view, show "Pairs well with" section with AI-generated synergy suggestions (e.g. Magnesium → Zinc, Creatine → Beta-Alanine)
- Knowledge Library: Goal-driven search — "What are you looking for?" input on library home screen, keyword search (sleep/focus/recovery/muscle) surfaces relevant compounds. Needs UltraPlan before building — touches data model, compound views, and potentially a new Edge Function.

---

## Useful paths
Project code root: `/Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack/`

Key files:
- `CLAUDE.md` — permanent rules
- `PROJECT_STATUS.md` — this file, handover context
- `SCHEMA_RULES.md` — DB schema and query rules
- `CLAUDE_OLD_ARCHIVE.md` — outdated reference only
