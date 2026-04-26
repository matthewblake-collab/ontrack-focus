# OnTrack — Chat Context File
## Paste this at the start of every new conversation

---

## HIGH PRIORITY RULES
1. At the start of every session AND every new feature, check the Awesome Claude Code list (github.com/hesreallyhim/awesome-claude-code) for any skills or tools that could help with what we are doing — suggest them to Matt before starting so he can install them
2. At the end of every session, remind Matt to run `/dream` in Claude Code to clean up memory

---

## What OnTrack is
A SwiftUI + MVVM iOS app with a Supabase backend. A group scheduling and wellness tracking app for sports teams and similar groups. Live on TestFlight as "OnTrack Focus" (bundle ID: com.blakeMatt.OnTrack).

## Tech stack
- SwiftUI (iOS 17+)
- Supabase (Swift package v2.41.1) — auth, database, RLS
- Xcode — IDE
- Claude Code in Terminal — how we build
- Physical iPhone for testing

## File path
`/Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack/`

## CLAUDE.md location
`/Users/matthewblake/Desktop/OnTrack/OnTrack/CLAUDE.md`

## Architecture
SwiftUI + MVVM + Supabase. Two coexisting observable patterns:
- `@Observable` macro — newer ViewModels (GroupVM, SessionVM, FriendsVM). Used with `@State`
- `ObservableObject/@Published` — legacy (AppState, HabitVM, SupplementVM, AuthVM). Used with `@StateObject`
- Never mix the two patterns

## Critical naming conventions
- `AppGroup` not `Group` (conflicts with SwiftUI)
- `AppSession` not `Session` (conflicts with Supabase)
- Friend IDs are `String` not `UUID` — never call `.uuidString` on them
- Background image: always `themeManager.currentBackgroundImage` — never hardcode asset names
- DB columns: `display_name`, `logged_date`, `taken_at`, `sleep`/`energy`/`wellbeing` — don't revert these

## What's fully built
- Auth + 4-page onboarding (display name, goals, avatar)
- Groups — create, join, delete, chat, stats, leaderboard, coach dashboard
- Group member session streaks — `session_streak` + `best_streak` on `group_members`; incremented/reset in `AttendanceViewModel.markAttendance`; displayed as 🔥N flame badge in `MemberRowView`; `GroupViewModel` has `incrementStreak` + `resetStreak` helpers
- Group chat read receipts — `message_reads` table (message_id, user_id, unique); `ChatMessage.reads: [String]` holds initials of readers; `fetchMessagesWithReads` joins reads on load + realtime refresh; overlapping avatar circles shown below message timestamp
- Sessions — recurring (weekly/fortnightly/monthly/custom), RSVP, availability, attendance, comments
- Session types — dropdown picker on create, teal badge on session cards, horizontal filter chips in SessionListView; `SessionViewModel.sessionTypes` static array; `session_type` column in DB (nullable text)
- Habits — personal + group, streaks, archive, friend invites
- Habit types — dropdown picker on create (`selectedHabitType` state in `AddHabitView`); UI only, no DB column
- Habit → link to group — group picker in `AddHabitView`, fetched via `MemberRow` wrapper struct decoding `groups(*)` join
- Supplements — stock tracking, daily logging, share via 6-char codes, vial calculator; name autocomplete from `supplement_types` DB table (`.ilike` prefix search, limit 6); custom types saved back on add
- Daily check-in — sleep/energy/wellbeing 1–10, HealthKit pre-fill
- Mental health — 30-day trends (Swift Charts), AI wellness insights (Anthropic API)
- HealthKit — sleep, RHR, steps, energy, VO2, weight, body fat (read-only)
- Friends — friend codes, search, requests, milestone feed
- Push notifications — permission dialog fixed (requestAuthorization wrapped in DispatchQueue.main.async, called from applicationDidBecomeActive with 2.0s asyncAfter delay after HealthKit); 5 smart local notification types; APNs token saved to DB
- Background photos — all 4 tabs use `themeManager.currentBackgroundImage` with `.grayscale(1.0)`, daily cycling through 23 assets
- ThemeManager — cycling background daily through 23 assets (asset names are `backround_X` with typo — matches asset catalog)
- OnboardingTooltip — first-launch overlay system (`OnboardingTooltip.swift`); `OnboardingManager` tracks seen screens via UserDefaults (`onboarding_seen_<screen>`); `.onboardingTooltip(screen:title:message:icon:)` modifier fully applied to all 4 tabs: DailyActionsView (home), GroupListView (groups), MentalHealthView (mentalhealth), NotificationsView (notifications)
- Stats reset — destructive "Reset My Stats" button in Settings → Data section; runs parallel async deletes on `habit_logs`, `daily_checkins`, `supplement_logs`, `attendance` for current user + clears `"checkin_completed_date"` UserDefaults key

## UI / Visual conventions
- All tab backgrounds use `themeManager.currentBackgroundImage` with `.grayscale(1.0)` + dark overlay
- Component cards/rows use `Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)` — NOT white/black opacity
- Full-screen background overlays use `Color.black.opacity(0.72)` with `.ignoresSafeArea()`
- LaunchScreenView and SignInView use dark background `Color(red: 0.06, green: 0.12, blue: 0.15)` with three-rect logo mark
- MentalHealthView uses same ZStack(alignment: .top) + GeometryReader structure as DailyActionsView; nav bar hidden; header in ScrollView with `.padding(.top, 8)`
- Chart lines: `Color(red: 0.2, green: 0.8, blue: 0.6)` with AreaMark gradient fill; axis labels `.white`; grid lines `Color.white.opacity(0.15)`

## Known issues / incomplete
1. NotificationsView — placeholder only, no real list
2. APNs end-to-end — token saved but server-side delivery not confirmed
3. Mental Health screen header sits slightly too low — padding issue deferred

## Tools installed in Claude Code
- Claude Mem — persistent memory across sessions (user scope). Memory at http://localhost:37777
- SwiftUI Expert Skill — auto-activates on SwiftUI files (AvdLee/SwiftUI-Agent-Skill)
- Supabase MCP — connected to live DB (project ref: wqkisslixduowewuaiae). Claude can see all 20 tables directly
- UI/UX Pro Max — auto-activates when building any UI (nextlevelbuilder/ui-ux-pro-max-skill)
- /dream — run at end of every session inside Claude Code to clean memory
- Awesome Claude Code — reference list for new tools: github.com/hesreallyhim/awesome-claude-code

## Roadmap (open)
1. Build out NotificationsView — currently placeholder only
2. Confirm APNs end-to-end delivery (token is saved, server-side push not yet tested)

## Key patterns
- All writes use upsert with `onConflict:` where needed
- Supabase RLS requires matching all policy columns in DELETEs
- `DailyCheckInViewModel` is lifted — instantiated in MainTabView, passed as `@Bindable`
- AI key is hardcoded in `AIInsightService.swift` — do not commit it
- Profile/Supplements are sheets from header buttons, not tabs
- **Supabase join queries** use a wrapper struct to decode nested relations, e.g. `struct MemberRow: Decodable { let group: AppGroup; enum CodingKeys: String, CodingKey { case group = "groups" } }` then `.map { $0.group }`
- **Background images:** always apply `.grayscale(1.0)` after `.scaledToFill()`. Asset names: `"groups_background"` and `"backround_2"`…`"backround_23"` (typo: `backround` not `background`) — do not "fix" the typo
- **Notification permission:** `requestAuthorization` wrapped in `DispatchQueue.main.async`, called from `applicationDidBecomeActive` via `DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)` (after HealthKit)
- **OnboardingManager:** `OnboardingManager.shared.hasSeenScreen(screen)` / `markScreenSeen(screen)` — UserDefaults key `"onboarding_seen_\(screen)"`
- **Session types:** stored in `SessionViewModel.sessionTypes` static `[String]` array; persisted to `session_type` DB column (nullable text); `AppSession.sessionType` optional String mapped via `CodingKeys`
- **Session streaks:** `GroupMember.sessionStreak` / `bestStreak` incremented/reset in `AttendanceViewModel.markAttendance` immediately after upsert; local `members` array updated in-place for instant UI refresh; `MemberRowView` shows 🔥N when streak > 0
- **Chat read receipts:** `GroupChatViewModel.markMessagesAsRead` upserts to `message_reads` on view appear; `fetchMessagesWithReads` joins reads and maps to `ChatMessage.reads: [String]` (initials); `MessageBubble` renders overlapping 18pt gradient circles below timestamp
- **Supplement autocomplete:** `AddSupplementView.fetchSuggestions` queries `supplement_types` with `.ilike("name", value: "\(query)%")` limit 6; `saveCustomType` upserts back on save with `onConflict: "name"`
- **iOS deployment target:** minimum is iOS 17.0 (was incorrectly set to 26.2 — now fixed)

## Daily Claude Code workflow
- Start: `cd ~/Desktop/OnTrack && claude --auto-run` — memory loads automatically
- End of session: type `/dream` in Claude Code to clean memory
- Search past sessions: `/mem-search [topic]`
- Sensitive info: wrap in `<private>...</private>`

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

Build and run via Xcode (open `OnTrack.xcodeproj`). From the command line:

```bash
# Build
xcodebuild -project OnTrack.xcodeproj -scheme OnTrack -sdk iphonesimulator build

# Run all unit tests
xcodebuild -project OnTrack.xcodeproj -scheme OnTrack -sdk iphonesimulator test

# Run a single test class
xcodebuild -project OnTrack.xcodeproj -scheme OnTrack -sdk iphonesimulator test -only-testing:OnTrackTests/MyTestClass

# Run a single test method
xcodebuild -project OnTrack.xcodeproj -scheme OnTrack -sdk iphonesimulator test -only-testing:OnTrackTests/MyTestClass/testMethodName
```

## Architecture

SwiftUI + MVVM app with Supabase as the backend. `AppState` is `ObservableObject` injected via `.environmentObject(appState)` and accessed with `@EnvironmentObject`.

**Two observable patterns in use — do not mix them up:**
- `@Observable` macro — used by `GroupViewModel`, `SessionViewModel`, `AttendanceViewModel`, etc. Instantiated with `@State` in views.
- `ObservableObject` / `@Published` — used by `AppState`, `HabitViewModel`, `SupplementViewModel`, `AuthViewModel`. Instantiated with `@StateObject` / `@ObservedObject` in views.

**Domain:** Groups of users create and manage sessions (events), RSVP, log availability windows, track attendance, and leave comments. Users also track personal habits and supplements via a Daily Actions tab.

**Entry point:** `OnTrackApp.swift` → `ContentView.swift` → `MainTabView` (logged in) or `SignInView` (logged out). `OnTrackApp` owns the `LaunchScreenView` (1.5s splash via `showLaunch` state) before handing off to `ContentView`.

**Auth gate:** `ContentView` checks `appState.currentUser != nil` (not `isLoggedIn`) to decide which root view to show. Authenticated users then see `OnboardingView` if `appState.hasCompletedOnboarding == false`, otherwise `MainTabView`.

**App lifecycle:** Uses `@UIApplicationDelegateAdaptor(AppDelegate.self)`. `AppDelegate` lives in `OnTrackApp.swift`. `UNUserNotificationCenter.current().delegate` is set in `didFinishLaunchingWithOptions`. Notification permission is requested from `applicationDidBecomeActive` (not `didFinishLaunchingWithOptions` — window isn't ready yet).

**Tab structure (4 tabs, default = Home):** Home (DailyActions) → Groups → Mental Health → Notifications. Profile and Supplements are no longer tabs — they are accessible via `person.circle.fill` / `pills.fill` icon buttons in the header of each tab, opening as sheets.

**Navigation flow:**
```
GroupListView → GroupDetailView → SessionListView → SessionDetailView
                                                  → CommentsView
                                                  → AvailabilityView → AddAvailabilityView
                                                  → AttendanceView
                               → GroupChatView (nav bar icon)
                               → GroupStatsView
                               → GroupLeaderboardView
DailyActionsView → HabitDetailView
                 → SessionDetailView (with group lookup)
                 → SupplementDetailView (sheet)
```

**Folder structure:**
```
OnTrack/
├── Core/
│   ├── SupabaseClient.swift      # Global `supabase` client instance
│   ├── AppState.swift            # ObservableObject — auth + profile state, injected app-wide; hasCompletedOnboarding (UserDefaults-backed @Published), completeOnboarding(), resetOnboarding()
│   ├── NotificationManager.swift # NSObject singleton (NOT @MainActor) — permission, APNs token, local notifications; lastKnownUserId set by scheduleSmartNotifications; refreshCheckInReminderIfNeeded() called on every app-become-active
│   ├── HealthKitManager.swift    # @Observable singleton — reads sleep, RHR, steps, active energy, distance, exercise, VO2 max, weight, body fat, height; requestAuthorization() + fetchAll() async; sleepScore() → Int 1–5
│   └── Constants.swift           # Table name constants (enum Tables)
├── Models/
│   ├── Profile.swift             # Profile → users; includes goals: [String]
│   ├── Group.swift               # AppGroup (renamed from Group to avoid SwiftUI conflict)
│   ├── GroupMember.swift
│   ├── Session.swift             # AppSession (renamed from Session to avoid Foundation conflict)
│   ├── RSVP.swift
│   ├── AvailabilityWindow.swift
│   ├── Attendance.swift
│   ├── Comment.swift
│   ├── Supplement.swift          # Supplement (incl. stockQuantity, stockUnits, doseAmount, doseUnits), SupplementLog, SupplementTiming enum
│   ├── Habit.swift               # Habit, HabitFrequency enum, HabitSummary (partial join for milestone feed)
│   ├── HabitLog.swift            # HabitLog (includes habit: HabitSummary? for joined queries), NewHabitLog
│   └── Friendship.swift          # Friendship, NewFriendship, FriendProfile (lightweight join), FriendCode, NewFriendCode, HabitMember, NewHabitMember, Milestone
├── ViewModels/
│   ├── Auth/
│   │   └── AuthViewModel.swift
│   ├── Groups/
│   │   └── GroupViewModel.swift       # @Observable — also defines incrementStreak / resetStreak (write session_streak + best_streak to group_members)
│   ├── Sessions/
│   │   ├── SessionViewModel.swift    # @Observable — also defines RecurrenceRule enum; fetchAllSessions() fetches across all groups
│   │   ├── RSVPViewModel.swift
│   │   ├── AvailabilityViewModel.swift
│   │   ├── AttendanceViewModel.swift
│   │   └── CommentViewModel.swift
│   ├── Supplements/
│   │   └── SupplementViewModel.swift # ObservableObject — supplementLogs, logSupplement, unlogSupplement, fetchSupplementLogs, deductStock, isLowStock
│   ├── Habits/
│   │   └── HabitViewModel.swift      # ObservableObject — toggle/increment/decrement, streaks, updateHabit
│   ├── Friends/
│   │   └── FriendsViewModel.swift    # @Observable — friends list, pending requests, friend codes, user search, habit invites, milestone feed
│   ├── AIInsightViewModel.swift      # @Observable — calls AIInsightService to generate a wellness tip; isLoading, insight, errorMessage, lastGenerated
│   └── CoachWellnessViewModel.swift  # @Observable — fetches last 7 days of check-ins/habits/attendance for all group members; builds MemberWellnessSummary array; generateTeamInsight() calls AIInsightService
├── Views/
│   ├── Auth/
│   │   └── OnboardingView.swift  # 4-page onboarding (Welcome, Features, Profile, Goals); also defines ChipWrapView, FlowLayout, ImagePicker; saves display_name, goals, avatar_url to profiles
│   ├── Groups/
│   │   ├── GroupDetailView.swift     # Also defines GroupInsightsGridView, GroupInsightCard, MemberRowView (🔥 streak badge); admin sees Coach Dashboard NavigationLink
│   │   ├── CoachDashboardView.swift  # Admin-only; also defines MemberWellnessCard, WellnessStatPill; takes group + memberProfiles [(id: UUID, name: String)]
│   │   └── GroupChatView.swift       # Also defines GroupChatViewModel, MessageBubble; includes read receipts (message_reads table, overlapping avatar circles below timestamp)
│   ├── Sessions/
│   │   ├── SessionDetailView.swift   # Requires both session: AppSession AND group: AppGroup
│   │   └── ...
│   ├── RSVP/
│   ├── Availability/
│   ├── Attendance/
│   ├── Supplements/
│   │   ├── SupplementsView.swift       # 3 tabs: Today, My Stack, Stock
│   │   ├── SupplementDetailView.swift  # Requires viewModel: SupplementViewModel
│   │   ├── AddSupplementView.swift     # Also defines SupplementRecurrence enum, CustomSupplementDatePicker; name autocomplete from supplement_types table; saves custom types on add
│   │   ├── StockOverviewView.swift     # Stock tab — quantity remaining, dose per use, low stock badge
│   │   ├── ShareStackView.swift
│   │   └── ImportStackView.swift
│   ├── Friends/
│   │   └── FriendsView.swift         # Also defines FriendRow, FriendRequestRow, PendingSentRow, SearchResultRow, FriendCodeSheet, AvatarView, FriendsFeedView, MilestoneCard, SectionHeader
│   ├── Habits/
│   │   ├── DailyActionsView.swift    # Also defines HabitRowView, DailySessionRowView, DailySupplementRowView, DailyItem enum
│   │   ├── HabitDetailView.swift     # Also defines InviteFriendsToHabitView, HabitCalendarGrid, EditHabitView (all support isPrivate)
│   │   └── AddHabitView.swift        # Includes isPrivate toggle + optional group link (fetches user's groups via group_members join on load)
│   ├── AIInsightCard.swift           # Card view using AIInsightViewModel — shows sparkles header, loading/error/insight states, Generate/Refresh buttons
│   └── Shared/
│       ├── MainTabView.swift         # 4 tabs: Home, Groups, Mental Health, Notifications (selectedTab defaults to 0); shows daily check-in sheet on first open each day; notification denied alert; Profile/Supplements open as sheets
│       ├── MentalHealthView.swift    # Hub: prominent check-in card (today's date) + inline 7-day trends chart card (with metric picker + "View Full Trends" button) + AIInsightCard + AppleHealthCard; imports Charts + Supabase; defines private InlineCheckIn struct
│       ├── AppleHealthCard.swift     # Displays HealthKit stats in a 2-col grid; shows Connect button if not authorized; refresh button re-calls fetchAll()
│       ├── NotificationsView.swift   # Placeholder — empty state bell.slash view
│       ├── ProfileView.swift         # Sections: avatar/name, My Stats (InsightsGridView), Display Name, Settings, Sign Out
│       ├── DailyCheckInView.swift    # Full-screen modal — sleep/energy/wellbeing rated 1–10 stars; upserts to daily_checkins (onConflict: "user_id,checkin_date"); stores today in UserDefaults "checkin_completed_date" on submit; ViewModel lifted to caller (MainTabView/MentalHealthView) — takes @Bindable var vm: DailyCheckInViewModel; pre-fills sleep+energy from HealthKit once per ViewModel lifetime (guarded by healthKitPrefilled flag)
│       ├── CheckInInsightsView.swift # "Wellbeing Trends" — line chart + 7-day avg + best/worst day cards; fetches last 30 days from daily_checkins; uses Swift Charts; Y-axis 0–10
│       ├── OnboardingTooltip.swift  # OnboardingManager (UserDefaults), OnboardingOverlay, OnboardingModifier, View.onboardingTooltip() extension
│       ├── SettingsView.swift        # Appearance/Background/Cards/Notifications/Data/About sections; Data section has Reset My Stats (destructive, confirmation dialog)
│       ├── StatusBadge.swift
│       └── LaunchScreenView.swift
└── Utilities/
AIInsightService.swift              # (root of OnTrack/ group) Singleton — calls Anthropic API directly via URLRequest; hardcoded API key (do not commit)
SupplementDoseCalculatorView.swift  # (root of OnTrack/ group) Vial-based dose calculator — steps for vial size, BAC water, desired dose; outputs units/ml result
```

## Key Conventions

- **Model naming:** `AppGroup` (not `Group` — conflicts with SwiftUI's `Group` view) and `AppSession` (not `Session` — conflicts with Supabase's `Session` type).
- **Supabase queries:** All use `.execute().value` for typed decoding. Snake_case DB columns mapped via `CodingKeys`.
- **Supabase RLS + DELETE:** When a DELETE is blocked by RLS, Supabase returns success with 0 rows and no Swift error — always include every column the RLS policy filters on (e.g. `created_by` for group deletes: `.eq("id", ...).eq("created_by", userId)`).
- **Recurrence:** `RecurrenceRule` enum (none/weekly/fortnightly/monthly/custom) defined in `SessionViewModel.swift`. Custom dates use a calendar picker (`CustomDatePickerView`). Recurring sessions share a `series_id` UUID.
- **Brand colours:** Teal-to-green gradient — `Color(red: 0.08, green: 0.35, blue: 0.45)` → `Color(red: 0.15, green: 0.55, blue: 0.38)`.
- **App icon:** `Assets.xcassets/AppIcon.appiconset/` — all PNGs cropped to edge-to-edge (no padding). Missing sizes generated as `icon_120.png` and `icon_152.png`.
- **Cycling background image:** `ThemeManager.currentBackgroundImage` returns the active background asset name, cycling **daily** through 23 images. Asset names in catalog use typo: `groups_background`, `backround_2`…`backround_23` (missing 'g'). The array in `ThemeManager.backgroundImageNames` matches this typo — do not "fix" it. All background `Image(...)` calls use this property with `.grayscale(1.0)` — never hardcode asset names. Views that use it must have `@EnvironmentObject private var themeManager: ThemeManager`.
- **Profile/Supplements access:** Both are sheets triggered from header buttons in each tab. All 4 tabs use custom in-scroll or in-ZStack headers with `.navigationBarHidden(true)` — no tab uses `.toolbar` for these buttons any more.
- **Friends access:** `GroupListView` header has a `person.2.fill` button that opens `FriendsSheetView` (teal gradient wrapper around `FriendsView`). `FriendsView` is not a tab — it is always presented as a sheet.
- **Habit privacy:** `Habit.isPrivate` (`is_private` DB column) — when true, friends see streak count but not the habit name. Set in `AddHabitView` and `EditHabitView`; written via `createHabit(isPrivate:)` and `updateHabit(_:name:targetCount:isPrivate:)` in `HabitViewModel`.
- **Friend IDs:** `Friendship.requesterId`/`receiverId`, `FriendProfile.id`, and `HabitMember.userId`/`id`/`habitId`/`invitedBy` are all `String` (UUID strings), not `UUID`. `FriendsViewModel` takes `userId: String` parameters throughout. `AvatarView` accepts `url: String?` and renders via `AsyncImage`. Never call `.uuidString` on these fields — they are already strings.
- **AI feature column names:** `daily_checkins` uses `sleep`/`energy`/`wellbeing` (not `sleep_score` etc.); `habit_logs` uses `logged_date` (not `completed_at`); `supplement_logs` uses `taken_at`. These have been corrected in `AIInsightViewModel` and `CoachWellnessViewModel` — do not revert.
- **Profile display name:** `Profile.displayName` (not `fullName`) — maps to `display_name` DB column.
- **`SupplementDoseCalculatorView`**: File lives at `OnTrack/SupplementDoseCalculatorView.swift` (directly in the `OnTrack` source folder, not in a subfolder). Previously named `PeptideCalculatorView.swift` — all references updated.
- **HealthKit:** Capability entitlement (`com.apple.developer.healthkit`) is in `OnTrack.entitlements`. `NSHealthShareUsageDescription` is in `Info.plist`. Authorization is called from `AppDelegate.applicationDidBecomeActive` and on login. `fetchAll()` is called once per calendar day from `applicationDidBecomeActive` — tracked via UserDefaults key `"healthkit_last_fetch_date"`. `DailyCheckInView` pre-fills sleep (via `sleepScore()`) and energy (step count → 1–10 bucket) once per ViewModel lifetime, guarded by `healthKitPrefilled`.
- **`DailyCheckInView` requires `themeManager`:** Added `@EnvironmentObject private var themeManager: ThemeManager` — it is presented as a sheet from `MainTabView` which injects `themeManager` via `.environmentObject`.
- **`DailyCheckInViewModel` is lifted:** Instantiated as `@State private var checkInVM = DailyCheckInViewModel()` in `MainTabView` and `MentalHealthView` — passed into `DailyCheckInView(vm: checkInVM)` so the ViewModel survives sheet dismiss/reopen. Before showing the sheet, callers call `checkInVM.reset()` then `checkInVM.prefillFromHealthKit()`.
- **UserDefaults keys:** `"checkin_completed_date"` (today's date string written on successful check-in submit, read by `scheduleSmartCheckInReminder` fast-path); `"healthkit_last_fetch_date"` (date of last HealthKit `fetchAll()`, checked each `applicationDidBecomeActive`).

## GroupDetailView Layout

Content order (top to bottom):
1. Group header — name, description, Edit Cover menu (admin only), invite code + share
2. Upcoming Sessions — inline list (up to 5, `proposed_at >= now`), "See All" → `SessionListView`
3. Group Stats — inline `GroupInsightsGridView` cards
4. View Stats button → `GroupStatsView`
5. Leaderboard button → `GroupLeaderboardView`
6. Members (x) — collapsed by default, expands with animation; each row uses `MemberRowView`; non-self members show Add Friend / Pending / checkmark based on friendship state; admin sees role management menu
7. Leave Group button — shown for all members

Chat is a `bubble.left.and.bubble.right.fill` icon in the navigation bar (top right) → `GroupChatView`. Admins also see a `plus.circle.fill` button in the nav bar that opens `CreateSessionView` as a sheet.

**Admin leave flow:** Alert with "Assign New Admin" (sheet to pick member → promote to owner → leave) / "Delete Group" / "Cancel". Delete uses `.eq("id", ...).eq("created_by", userId)` to satisfy RLS.

**Non-admin leave flow:** Removes from `group_members` + deletes RSVPs for future sessions (`proposed_at >= now`). Past `attendance` records are preserved.

## Notifications

`NotificationManager` is a `@MainActor` singleton (`NSObject` subclass for `UNUserNotificationCenterDelegate`).

- **Permission timing:** Call `requestPermission()` from `AppDelegate.applicationDidBecomeActive` — NOT `didFinishLaunchingWithOptions` (window not ready yet, dialog is silently suppressed).
- **Status check:** `requestPermission()` always calls `getNotificationSettings()` first and prints the current status. If `.denied`, it returns `false` without prompting — caller shows a "go to Settings" alert.
- **APNs token flow:** `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` → `NotificationManager.handleDeviceToken(_:)` stores it → `saveTokenToProfile(userId:)` persists to `profiles.push_token` once auth is available (triggered by `.onChange(of: appState.currentUser?.id)` in `OnTrackApp`).
- **Smart notifications:** On login, `OnTrackApp` calls `scheduleSmartNotifications(userId:)` which sets `lastKnownUserId` and runs all 5 smart reminders. On every `applicationDidBecomeActive`, `refreshCheckInReminderIfNeeded()` re-evaluates the check-in reminder using the stored userId.
- **Smart notification methods (all on `NotificationManager`):**
  - `scheduleSmartCheckInReminder` — UserDefaults fast-path via `"checkin_completed_date"` key; skips Supabase if already checked in today; back-fills UserDefaults when Supabase confirms check-in exists
  - `scheduleHabitStreakReminder` — 8pm if any habits incomplete; queries `habits` by `created_by` (not `user_id`)
  - `scheduleLowWellnessAlert` — fires if this week's avg wellness is 0.5+ below last week
  - `scheduleSupplementReminder` — 8pm if no supplement logs today
  - `scheduleTeamMoraleAlert` — fires for group owners if team wellness dropped vs prior week
- **Session reminders:** `scheduleSessionReminder(session:minutesBefore:)` — identifier pattern `"session-{uuid}-{n}min"`. `cancelSessionReminder(sessionId:)` removes 60/30/15min variants.

## Supabase Tables

| Table | Key columns |
|---|---|
| `profiles` | `id`, `display_name`, `avatar_url`, `push_token`, `goals` (text[]), `created_at` |
| `groups` | `id`, `name`, `description`, `invite_code`, `created_by`, `created_at`, `cover_image_url` |
| `group_members` | `id`, `group_id`, `user_id`, `role` ("owner" or "member"), `joined_at`, `session_streak` (Int), `best_streak` (Int) |
| `group_messages` | `id`, `group_id`, `user_id`, `content`, `created_at` |
| `message_reads` | `message_id`, `user_id` — unique on `(message_id, user_id)` |
| `supplement_types` | `name` (unique), `is_global` (bool), `created_by` (uuid nullable) |
| `sessions` | `id`, `group_id`, `title`, `description`, `location`, `proposed_at`, `status`, `created_by`, `created_at`, `series_id`, `recurrence_rule`, `session_type` (text, nullable) |
| `rsvps` | `id`, `session_id`, `user_id`, `status`, `updated_at` — unique on `(session_id, user_id)` |
| `availability_windows` | `id`, `session_id`, `user_id`, `starts_at`, `ends_at`, `created_at` |
| `attendance` | `id`, `session_id`, `user_id`, `attended`, `marked_by`, `marked_at` — unique on `(session_id, user_id)` |
| `comments` | `id`, `session_id`, `user_id`, `content`, `created_at` |
| `daily_checkins` | `id`, `user_id`, `checkin_date` (date string "yyyy-MM-dd"), `sleep`, `energy`, `wellbeing` (Int 1–10), `created_at` |
| `supplements` | `id`, `user_id`, `name`, `dose`, `timing`, `custom_time`, `days_of_week`, `notes`, `reminder_enabled`, `is_active`, `stock_quantity` (Double?), `stock_units` (String?), `dose_amount` (Double?), `dose_units` (String?), `created_at` |
| `supplement_logs` | `id`, `supplement_id`, `user_id`, `taken`, `taken_at` (date string), `created_at` — unique on `(supplement_id, user_id, taken_at)` |
| `habits` | `id`, `created_by`, `group_id`, `name`, `frequency`, `days_of_week`, `weekly_target`, `monthly_target`, `target_count`, `is_archived`, `is_private`, `created_at` |
| `habit_logs` | `id`, `habit_id`, `user_id`, `logged_date` (date string), `count`, `created_at` |
| `shared_stacks` | `id`, `code` (unique 6-char), `created_by`, `name`, `supplements` (jsonb array) |
| `friendships` | `id`, `requester_id`, `receiver_id`, `status` ("pending"/"accepted"/"declined"), `created_at`, `updated_at` |
| `friend_codes` | `id`, `user_id`, `code` (unique 6-char alphanumeric), `created_at` |
| `habit_members` | `id`, `habit_id`, `user_id`, `invited_by`, `status` ("pending"/"accepted"/"declined") |

## Push Notifications Status

**Capability:** Push Notifications capability is added in Xcode (Signing & Capabilities).

**NotificationManager:** `Core/NotificationManager.swift` exists. `NSObject` subclass, NOT `@MainActor`. `requestPermission()` is synchronous, closure-based (no async/await) — calls `getNotificationSettings { }` then `requestAuthorization(options:completionHandler:)` directly. `DispatchQueue.main.async` used explicitly for `registerForRemoteNotifications()`.

**Call sites attempted (all present in code):**
1. `AppDelegate.applicationDidBecomeActive` — direct synchronous call, no Task wrapper
2. `MainTabView.onAppear` — direct synchronous call
3. `OnTrackApp.init()` — previously attempted via `Task { @MainActor in }`, since removed

**Current approach (fixed):**
- `requestPermission()` call in `applicationDidBecomeActive` wrapped in `DispatchQueue.main.asyncAfter(deadline: .now() + 2.0)` (2s delay, after HealthKit init)
- Inside `requestPermission()`, the `requestAuthorization(...)` call in `.notDetermined` branch is wrapped in `DispatchQueue.main.async { }`
- Permission dialog now appears correctly on device.

## Dependencies

Managed via Swift Package Manager. Key packages:
- `supabase-swift` 2.41.1 — Supabase client (auth, database, storage, realtime)
- `swift-crypto`, `swift-asn1` — Transitive crypto dependencies
- `swift-clocks`, `swift-concurrency-extras` — Point-Free async utilities (transitive)
