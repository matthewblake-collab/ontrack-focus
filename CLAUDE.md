# CLAUDE.md — OnTrack Focus (iOS)

SwiftUI + MVVM iOS app on Supabase. App/TestFlight name OnTrack Focus, bundle ID `com.blakeMatt.OnTrack`.
Source lives in `OnTrack/` under this repo root.

## Build and test
- Build (from this directory):
  `xcodebuild -scheme OnTrack -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'`
- Before any xcodebuild run: `pkill -f xcodebuild` and `rm -rf ~/Library/Caches/org.swift.swiftpm` (hung builds, SPM locks).
- 10-minute build timeout: if exceeded, stop and report the last 50 lines instead of retrying.
- Schemes: `OnTrack`, `OnTrackWidgetExtension`. Test targets `OnTrackTests` and `OnTrackUITests` exist; no test command
  has been verified. Confirm the scheme's test action before relying on `xcodebuild test`.
- UI edits: render the affected `#Preview` with `/capture` before committing. A compile is not a design check.

## Names that must not drift
- `AppGroup`, never `Group`. `AppSession`, never `Session`.
- Friend IDs are `String`, not `UUID`. Never call `.uuidString` on a friend ID.
- `Profile.displayName` maps to `display_name`.
- The background asset typo `backround_X` is intentional. Never rename it.
- Never rename existing models, files, DB columns or asset names without approval.

## Observable ownership split (never mix in one view tree)
- `@Observable`, instantiated with `@State`: `GroupViewModel`, `SessionViewModel`, `AttendanceViewModel`,
  `FriendsViewModel`, `GroupStatusVM`, `FeedViewModel`.
- `ObservableObject` / `@Published`, instantiated with `@StateObject` or `@ObservedObject`: `AppState`, `HabitViewModel`,
  `SupplementViewModel`, `AuthViewModel`.
- On text-input `onChange`, compare the new String value directly. A `@Published` Bool gate fires several times per
  keystroke (the autocomplete double-tap bug).

## SwiftUI traps
- `swipeActions` only works in `List`. Inside `LazyVStack` use `.contextMenu` or a manage sheet.
- "Unable to type-check expression": drop `@ViewBuilder` from the computed property and use an explicit `return`.
- Backgrounds come only from `themeManager.currentBackgroundImage` (never a hard-coded asset name), with
  `.grayscale(1.0)` after `.scaledToFill()`.
- Card colour `Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)`; full-screen overlay `Color.black.opacity(0.72)`.
  Keep the dark visual system; no white-card patterns.

## Supabase
- No new tables, columns, relations or backend workflows without explicit approval.
- Read `SKILL_ontrack_rls_safety.md` before ANY policy or UUID change. Schema rules: `SCHEMA_RULES.md`.
- Habits queries filter on `created_by`, never `user_id`.
- DELETE under RLS: include every policy-relevant column in the filter.
- Typed decoding with `.execute().value`. Chain `.eq()` before `.select()`. Use `upsert(onConflict:)` where needed.
- Prefer the SDK's `Decodable` support over manual `JSONSerialization`.
- `.from()` → `.rpc()`: decode into a small struct (e.g. `struct GroupLookup: Decodable { let id: UUID; let name: String }`),
  never into full models like `AppGroup` or `Friendship`, whose non-optional fields may be missing.
- Before reverting an RPC to `.from()`, check whether RLS blocks non-member access. If it does, the RPC is required: fix the
  decode struct, not the approach.
- Check the Supabase Swift SDK version in `Package.resolved` before writing query code; signatures change between versions.

## Local keys (UserDefaults)
`checkin_completed_date`, `healthkit_last_fetch_date`, `onboarding_seen_<screen>`, `tooltip_seen_<id>`,
`biometric_auth_enabled`, `biometric_prompt_shown` (once per device). Screen overlays (`OnboardingTooltip.swift`, via
`OnboardingManager.shared`) and button tooltips (`ButtonTooltip.swift`, direct UserDefaults) are separate systems.

## Release
- App Store Connect API key `9SJ6J5WR4U` (issuer `5b0f9937-7671-4ee9-a874-3097a137c780`), key file
  `~/.appstoreconnect/private_keys/AuthKey_9SJ6J5WR4U.p8`. Before any TestFlight or publishing work, check the Team ID,
  API key, `gh` auth and SSH keys exist.
- Before a Netlify deploy, check whether the change is already live. Don't redeploy identical changes.
