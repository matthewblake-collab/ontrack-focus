---
paths: ["**/*.swift"]
---

## Observable pattern rules
Two observable patterns exist and must not be mixed.

### `@Observable`
- Used for newer view models: `GroupViewModel`, `SessionViewModel`, `AttendanceViewModel`, `FriendsViewModel`, `GroupStatusVM`, `FeedViewModel`
- Instantiate with `@State` in views

### `ObservableObject` / `@Published`
- Used for legacy/shared state: `AppState`, `HabitViewModel`, `SupplementViewModel`, `AuthViewModel`
- Instantiate with `@StateObject` or `@ObservedObject`

## SwiftUI global patterns
- `swipeActions` requires `List`. Inside `LazyVStack` use `.contextMenu` or a manage sheet instead.
- For `onChange` handlers on text inputs, compare the new String value directly. Do NOT use a `@Published` Bool flag as a gate — `@Published` fires multiple times per keystroke and causes timing bugs (autocomplete double-tap pattern).
- For "unable to type-check expression" compile errors, remove `@ViewBuilder` from the computed property and use an explicit `return` — the DailyActionsView extraction pattern already does this.

## Naming rules
- Use `AppGroup`, never `Group`
- Use `AppSession`, never `Session`
- Friend IDs are `String`, not `UUID`
- Never call `.uuidString` on friend IDs
- `Profile.displayName` maps to `display_name`
- Do not rename the intentional background asset typo `backround_X`

## UI rules
- Background image must always come from `themeManager.currentBackgroundImage`
- Do not hardcode background asset names
- Apply `.grayscale(1.0)` to background images after `.scaledToFill()`
- Card background color:
  `Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)`
- Full-screen overlay color:
  `Color.black.opacity(0.72)`
- Keep the existing dark visual system
- Do not introduce white-card UI patterns that clash with the app style

## Onboarding & tooltip systems
Two distinct systems — do not confuse them.

### Screen-level onboarding overlays (`OnboardingTooltip.swift`)
- Full-screen dimmed overlay with icon, title, message, and "Got it" button
- Applied to NavigationStack-level views via `.onboardingTooltip(screen:title:message:icon:)`
- Tracks via `OnboardingManager.shared` using `onboarding_seen_<screen>` keys
- Applied to: home, groups, mentalhealth, friends, sessions

### Button-level tooltips (`ButtonTooltip.swift`)
- Small popover card with triangle arrow pointing at the target button
- Applied to any view via `.buttonTooltip(key:title:message:direction:)`
- `direction`: `.above` / `.below` / `.trailing` — controls which side the card appears
- Tracks via `UserDefaults` directly using `tooltip_seen_<id>` keys
- Dim: `Color.black.opacity(0.4).ignoresSafeArea()` — fills the full screen
- Card position uses local button size only (`geo.size` from GeometryReader inside overlay); `UIScreen.main.bounds.width` used for x clamping
- Arrow: 12×8pt triangle `TooltipArrow` shape (now `internal`, not `private`) above (`.below`) or below (`.above`) the card body
- **Placement rule:** Apply `.buttonTooltip` to the outermost container (ZStack or NavigationStack-level view), never to a button inside a ScrollView or toolbar — overlays on inner views are clipped by scroll content and UIKit nav bars
- For toolbar buttons specifically, use an inline `@State + .onAppear + .overlay` pattern on the NavigationStack's VStack instead of `.buttonTooltip` directly
- Do NOT apply `.buttonTooltip` directly to a `Menu` — apply it to the containing HStack/VStack instead
- Currently applied to:
  - Groups header HStack (contains `+` menu) → `tooltip_seen_groups_add`
  - DailyActions `+` button → `tooltip_seen_home_add`
  - MentalHealth outermost ZStack → `tooltip_seen_checkin`
  - Supplement timing icon → `tooltip_seen_supplement_stock`

## Key feature behaviours
- `MentalHealthView` check-in card shows green "Completed today ✓" state by reading `checkin_completed_date` from UserDefaults — same key written by `DailyCheckInViewModel.submit()`
- `GroupViewModel` fetches next upcoming session per group into `nextSessions: [UUID: AppSession]` — called at end of `fetchGroups()`, displayed as "📅 Session today/tomorrow/in N days" in `GroupListView` group cards
- On onboarding completion, an auto friend request is sent from Matt's user ID (`d4513d7c-0acc-4917-83b3-cb350a09a5f7`) to every new user — skipped if the new user IS Matt
- `FeedView` empty state shows "Share Friend Code" and "Invite via Messages" CTAs — `FriendCodeSheet` is presented directly from `FeedView` using `appState.currentUser?.id.uuidString`
- `GroupDetailView` leave/delete: if `members.count <= 1`, the admin skips the assign-admin alert and goes straight to `deleteGroup()` — both the Leave button action and `leaveGroup()` itself guard on this

## Auth features
- **Sign in with Apple** — uses Supabase Apple provider. Services ID: `com.blakeMatt.OnTrack.siwa`. JWT key expires ~Oct 2026. Implemented in `AuthViewModel.signInWithApple()` via `OpenIDConnectCredentials`. On first sign-in, inserts a `profiles` row using Apple's `fullName` credential (only provided on first auth). `SignInView` and `SignUpView` both show a `SignInWithAppleButton`.
- **Face ID / Touch ID biometric re-login** — `BiometricAuthManager` (singleton, `@MainActor`) in `Core/BiometricAuthManager.swift`. Credentials stored in Keychain under service `com.blakeMatt.OnTrack`, account `userCredentials`, as JSON. `NSFaceIDUsageDescription` must be set in `Info.plist`. Enrollment prompt is shown once per device (gated by `biometric_prompt_shown` UserDefaults key) — triggered via `NotificationCenter` notification `.biometricEnrollmentNeeded` posted from `AuthViewModel` after successful login, received by `ContentView` which owns the `BiometricEnrollmentSheet`. Auto-attempt on launch runs from `ContentView.tryBiometricIfEnabled()` via a dark holding screen to prevent `SignInView` flash. Apple users (empty stored password) re-auth via `AppState.checkSession()`; email users re-auth via `supabase.auth.signIn`.

## DailyActionsView row rendering
- Uses `ScrollView { LazyVStack(spacing: 8) { } .padding(.horizontal, 16) }` — NOT a `List`. Do not reintroduce `List`.
- `listRowBackground`, `listRowSeparator`, `listRowInsets` are List-only modifiers — do not use them here
- Habit rows use `.contextMenu { }` for Archive action (not `.swipeActions` — those require `List`)
- Each row has `.id(item.id)` so `ScrollViewReader.scrollTo()` works for the "Complete Now" button
- `HabitRowView` background order: `.padding(.vertical, 6)` → `.background(RoundedRectangle...)` — no outer `.padding(.horizontal)` since `LazyVStack` provides the 16pt screen-edge gap
- `DailySupplementRowView` background order: `.padding(.horizontal, 16).padding(.vertical, 6)` → `.background(RoundedRectangle...)` — internal content padding, card fills `LazyVStack` width

## App structure rules
- Main tabs are:
  1. Home (`DailyActionsView`)
  2. Groups (`GroupListView`)
  3. Supplements (`SupplementsView`)
  4. Wellbeing (`MentalHealthView`)
  5. Friends (`FriendsTabView`)
- Notifications is NOT a tab — it is presented as a sheet via a bell button in the header of each tab
- Profile is a sheet from a header button, not a tab
- Supplements is a full tab — do not present it as a sheet. Internal sub-tabs are: Protocol / My Stack / Stock (formerly Today / My Stack / Stock). "Today" tab was removed — supplements in DailyActionsView are driven by `inProtocol = true` supplements only.
- Friends is a full tab with three sub-tabs: Feed / Friends / Requests
- `DailyCheckInViewModel` is lifted and reused, not recreated on every sheet open — defined inside `Views/Shared/DailyCheckInView.swift`, not a standalone file
- `OnboardingView` is at `Views/Auth/OnboardingView.swift`, not `Views/Onboarding/`

## Crash reporting
- Sentry (sentry-cocoa 8.58.1) via SPM. DSN stored as `SentryDSN` key in Info.plist, read at runtime
- Active in Release builds only — wrapped in `#if !DEBUG` guard in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
- Tracing/profiling fully disabled — crash reporting + breadcrumbs only
- User tagging: `SentrySDK.setUser(User(userId:))` after profile fetch in `AppState.fetchProfile`. Cleared via `setUser(nil)` in `signOut()`. User ID only — never email or display name
- Sentry dashboard: https://ontrack-focus.sentry.io

## Product analytics
- PostHog (posthog-ios 3.55.0) via SPM. `PostHogAPIKey` + `PostHogHost` in Info.plist, read at runtime
- US cloud: host `https://us.i.posthog.com`, project 390657
- Active in Release builds only — wrapped in `#if !DEBUG` in AppDelegate, called via `Task { @MainActor in … }` because AppDelegate callback is not MainActor-isolated
- No Session Replay, no autocapture beyond standard app lifecycle events
- User identification via `AnalyticsManager.shared.identify(userId:)` after profile fetch in `AppState.fetchProfile`. Cleared via `reset()` in `signOut()`. User ID only — never email or display name
- 6 events currently wired:
  - `app_open` — AppDelegate launch
  - `onboarding_completed` — AppState.completeOnboarding()
  - `group_created` — GroupViewModel createGroup success
  - `session_rsvp` — RSVPViewModel setRSVP success, includes status property
  - `habit_logged` — HabitViewModel.toggleHabit insert-success branch only (increment/decrement of same-day reps intentionally not tracked)
  - `checkin_submitted` — DailyCheckInView submit success
- Opt-out: toggle in SettingsView Privacy section. `analytics_opt_out` UserDefaults key. When on, all AnalyticsManager methods no-op and PostHog SDK calls `optOut()`
- Manager file: `Core/AnalyticsManager.swift` — singleton `static let shared`, `@MainActor`
- Dashboard: https://us.posthog.com/project/390657

## Build and call-site rules
- After every Swift/SwiftUI code edit, run a build to verify compilation before moving to the next task. Never batch multiple edits without an intermediate build check.
- When refactoring any ViewModel property or function signature, grep the entire project for all usages before reporting done — missed call sites are a recurring issue
