# Realtime Sync Test Plan + Results

**Project:** `wqkisslixduowewuaiae` (OnTrack)
**Migration:** `20260514130000_realtime_publications.sql` applied 2026-05-14
**Matt UUID:** `d4513d7c-0acc-4917-83b3-cb350a09a5f7`

## What the F12 migration changed

1. **`supabase_realtime` publication members** — before F12 only `group_messages` was published. After F12 (8 tables added):

   | Table | Status |
   |---|---|
   | daily_checkins | ✅ added |
   | supplements | ✅ added |
   | supplement_logs | ✅ added |
   | user_protocols | ✅ added |
   | body_metrics | ✅ added |
   | health_journal | ✅ added |
   | blood_markers | ✅ added |
   | user_discount_unlocks | ✅ added |

   _Implication:_ F4 (Overview), F5 (Supplements), F6 (Bloodwork), F8 (Journal) realtime listeners were silently no-ops before this migration. They are now live.

2. **REPLICA IDENTITY FULL** set on all 7 mutable tables so UPDATE / DELETE events emit the full row to subscribers (default is PK-only).

3. **`updated_at` triggers** on `user_protocols` and `dashboard_layouts` via a new `public.set_updated_at()` trigger function (SECURITY DEFINER, search_path locked).

## Sync matrix

Latency column is the design target — <3s end-to-end. Visual confirmation = user-driven UAT (see below).

| Table | iOS writer | iOS reader | Web writer | Web reader | Web subscribed | iOS subscribed | Target latency |
|---|---|---|---|---|---|---|---|
| `daily_checkins` | DailyCheckInView | many (incl. Readiness, Overview) | (read-only, prompts iOS) | Overview page | ✅ `useRealtime('daily_checkins', INSERT/UPDATE)` in OverviewClient | ❌ none (iOS owns writes) | <3s |
| `supplements` | AddSupplementView / Edit | SupplementViewModel | SupplementEditDrawer, PrefillPrompt | SupplementsClient | ✅ `useRealtime('supplements', UPDATE)` in SupplementsClient | ❌ refresh on foreground (next fetch) |  <3s web, on-foreground iOS |
| `supplement_logs` | QuickLogViewModel, SupplementViewModel | SupplementViewModel | (read-only in F5) | SupplementsClient, OverviewClient | ✅ `useRealtime('supplement_logs', INSERT)` | ❌ owned by iOS | <3s web |
| `user_protocols` | ProtocolViewModel (iOS F2) | ProtocolViewModel | (read-only in F2-F11) | OverviewClient (protocol badge), BloodworkClient | ❌ no subscription (server-fetch only) | ❌ refresh on Profile re-appearance | <3s pending listener |
| `body_metrics` | (none yet — Apple Health import deferred) | (none) | BodyMetricsForm | BiometricsClient | ✅ `useRealtime('body_metrics', INSERT)` | ❌ owned by web | <3s web |
| `health_journal` | (none yet — F8 Quick Log integration deferred) | (none yet) | NewEntryForm | JournalClient | ✅ `useRealtime('health_journal', INSERT)` | ❌ no iOS consumer yet | <3s web |
| `blood_markers` | (manual entry deferred) | (none yet) | AddPanelForm | BloodworkClient | ✅ `useRealtime('blood_markers', INSERT)` | ❌ no iOS consumer yet | <3s web |
| `user_discount_unlocks` | (none — iOS reads count) | DashboardEntryViewModel (badge load) | PartnerBadge, OfferCard | DashboardEntryCard, OfferCard, OffersClient | ❌ not yet — query-on-load only | ❌ query-on-load only | manual refresh |

## End-to-end tests

### Test 1 — INSERT daily_checkin → web Overview updates <3s
- **Trigger (run from terminal):**
  ```bash
  NEW_SR=$(supabase projects api-keys --project-ref wqkisslixduowewuaiae --output json | python3 -c "import sys,json; keys=json.load(sys.stdin); print(next(k['api_key'] for k in keys if k['name']=='service_role'))")
  MATT_ID=d4513d7c-0acc-4917-83b3-cb350a09a5f7
  DATE=$(date -u +%Y-%m-%d)
  curl -sS -X POST "https://wqkisslixduowewuaiae.supabase.co/rest/v1/daily_checkins" \
    -H "apikey: $NEW_SR" -H "Authorization: Bearer $NEW_SR" -H "Content-Type: application/json" -H "Prefer: resolution=merge-duplicates" \
    -d "{\"user_id\":\"$MATT_ID\",\"checkin_date\":\"$DATE\",\"sleep\":8,\"energy\":7,\"wellbeing\":8,\"mood\":7,\"stress\":3}"
  ```
- **Expected:** Overview's TodayCard / Sparklines update without page refresh within 3s.
- **Plumbing status:** ✅ `daily_checkins` in publication, OverviewClient subscribes to INSERT + UPDATE.
- **Visual confirmation:** ⏳ pending user-driven UAT (open `/dashboard/overview` in a browser, run the curl, observe).

### Test 2 — Web supplement dose UPDATE → iOS reflects on next foreground
- **Trigger:** in web `/dashboard/supplements`, click Edit on a supplement → change dose → Save.
- **Expected:** the UPDATE hits `public.supplements`. iOS `SupplementViewModel` re-fetches on next `.task` (foregrounding the supplements screen).
- **Plumbing status:** ✅ supplements in publication w/ REPLICA IDENTITY FULL. iOS doesn't yet have a realtime listener — relies on its existing fetch-on-appear pattern.
- **Visual confirmation:** ⏳ pending user-driven UAT (web edit → iOS background→foreground → confirm new dose visible).

### Test 3 — Web new health_journal entry → iOS appearance
- **Trigger:** in web `/dashboard/journal`, "+ New entry" → save.
- **Expected:** the INSERT hits `public.health_journal`.
- **Plumbing status:** ✅ health_journal in publication. **Gap:** iOS has no health_journal consumer yet, so there is no UI surface to "appear in" today. Building an iOS journal feed view is a deliberate post-F12 deferral.
- **Visual confirmation:** ⏳ deferred — iOS journal screen not yet built.

### Test 4 — INSERT blood_markers row → web Bloodwork updates <3s
- **Already executed during F12 plumbing verification:**
  - Row inserted via service_role: `id=2ed3c916-86b5-433e-9645-4ca307098987`, marker `sync_test_marker`, value 42, ref 40-50, ts 2026-05-14T09:53:55.000Z.
- **Plumbing status:** ✅ blood_markers in publication, BloodworkClient subscribes to INSERT.
- **Visual confirmation:** ⏳ pending — if a browser session was open on `/dashboard/bloodwork` at the time, a new marker card titled "Sync Test Marker" should have appeared within 3s.
- **Cleanup:**
  ```bash
  curl -sS -X DELETE "https://wqkisslixduowewuaiae.supabase.co/rest/v1/blood_markers?id=eq.2ed3c916-86b5-433e-9645-4ca307098987" \
    -H "apikey: $NEW_SR" -H "Authorization: Bearer $NEW_SR"
  ```

## Known gaps (deferred post-F12)

1. **iOS user_protocols realtime listener.** The plan called for "extend existing Supabase listeners to cover user_protocols". Today the iOS app owns all writes to this table (no web mutation surface exists), so there's no cross-app sync need. If the web dashboard later adds a protocol-edit flow, add a postgresChange subscription in `AppState` or `ProtocolViewModel` mirroring the `GroupChatView` pattern (`Views/Groups/GroupChatView.swift:214–227`).

2. **iOS health_journal realtime listener.** Same shape — would need a journal view on iOS first. Building such a view is out of F12 scope but the pattern is identical.

3. **user_discount_unlocks realtime on web** (the badge count + matched-offers list). Currently query-on-load; could be upgraded to realtime if cross-tab refresh becomes a problem.

4. **Visual UAT.** All 4 end-to-end tests need a browser + iOS device. The plumbing (publication membership, REPLICA IDENTITY, listeners in code) is in place. Run the 4 trigger commands above with the relevant dashboard tab open to verify <3s latency.

## Plumbing PASS summary

| Check | Status |
|---|---|
| `supabase_realtime` exists | ✅ |
| 8 target tables in publication | ✅ |
| `REPLICA IDENTITY FULL` on 7 mutable tables | ✅ |
| `set_updated_at()` trigger function exists | ✅ |
| `updated_at` triggers on user_protocols + dashboard_layouts | ✅ |
| Test INSERT round-trip via service_role | ✅ |
| Web subscription code present (5 tables) | ✅ |
| iOS subscription code present (user_protocols, health_journal) | ❌ deferred |
| End-to-end latency <3s visually confirmed | ⏳ user UAT |
