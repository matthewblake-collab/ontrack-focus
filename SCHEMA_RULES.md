# SCHEMA_RULES.md

## Schema safety rule
Never invent a new Supabase table, column, relation, or backend workflow just because it is a common app pattern.
Only use schema explicitly listed here, in existing code, or in explicitly approved changes.

## Core model / DB naming rules
- `Profile.displayName` maps to `display_name`
- `daily_checkins` uses `sleep`, `energy`, `wellbeing`
- `habit_logs` uses `logged_date`
- `supplement_logs` uses `taken_at`
- `sessions.session_type` is nullable text
- `sessions.created_by` is the UUID of the session creator (not `creator_id`)
- Friend IDs are `String`, not `UUID`

## Query rules
- Use typed Supabase decoding with `.execute().value`
- Use `upsert` with `onConflict:` where needed
- For DELETEs under RLS, include all policy-relevant columns in the filter
- Do not assume DELETE failure will throw a Swift error — RLS may return success with 0 rows

---

## Key tables

### `profiles`
- `id`, `display_name`, `avatar_url`, `push_token`, `goals`, `created_at`

### `groups`
- `id`, `name`, `description`, `invite_code`, `created_by`, `created_at`, `cover_image_url`

### `group_members`
- `id`, `group_id`, `user_id`, `role`, `joined_at`, `session_streak`, `best_streak`

### `group_messages`
- `id`, `group_id`, `user_id`, `content`, `created_at`

### `message_reads`
- `message_id`, `user_id`
- Unique: `(message_id, user_id)`

### `sessions`
- `id`, `group_id`, `title`, `description`, `location`, `proposed_at`, `status`, `created_by`, `created_at`, `series_id`, `recurrence_rule`, `session_type`
- `visibility` — text, default `'private'`. Set to `'friends'` to make a session joinable from the feed. Confirmed present in production.

### `attendance`
- `id`, `session_id`, `user_id`, `attended` (Bool), `marked_by`, `marked_at`
- Unique: `(session_id, user_id)`
- Uses `attended: Bool`. `marked_at` has DB default `now()` so it is auto-filled on insert.

### `rsvps`
- `id`, `session_id`, `user_id`, `status`, `updated_at`
- Unique: `(session_id, user_id)`

### `availability_windows`
- `id`, `session_id`, `user_id`, `starts_at`, `ends_at`, `created_at`

### `comments`
- `id`, `session_id`, `user_id`, `content`, `created_at`

### `daily_checkins`
- `id`, `user_id`, `checkin_date`, `sleep`, `energy`, `wellbeing`, `created_at`

### `habits`
- `id`, `created_by`, `group_id`, `name`, `frequency`, `days_of_week`, `weekly_target`, `monthly_target`, `target_count`, `is_archived`, `is_private`, `created_at`

### `habit_logs`
- `id`, `habit_id`, `user_id`, `logged_date`, `count`, `created_at`

### `habit_members`
- `id`, `habit_id`, `user_id`, `invited_by`, `status`

### `supplements`
- `id`, `user_id`, `name`, `dose`, `timing`, `custom_time`, `days_of_week`, `notes`, `reminder_enabled`, `is_active`, `stock_quantity`, `stock_units`, `dose_amount`, `dose_units`, `created_at`, `in_protocol`
- `in_protocol` (Bool, default false) — true = supplement appears in Protocol tab and DailyActionsView. My Stack shows all active supplements regardless of this flag.

### `supplement_logs`
- `id`, `supplement_id`, `user_id`, `taken`, `taken_at`, `created_at`
- Unique: `(supplement_id, user_id, taken_at)`

### `supplement_types`
- `name`, `is_global`, `created_by`

### `shared_stacks`
- `id`, `code`, `created_by`, `name`, `supplements`

### `friendships`
- `id`, `requester_id`, `receiver_id`, `status`, `created_at`, `updated_at`

### `friend_codes`
- `id`, `user_id`, `code`, `created_at`

### `feed_likes`
- `liker_id`, `target_type` (`"session"` or `"streak"`), `target_id`, `target_owner_id`
- Used by FeedViewModel for liking feed items. Confirmed present in production.
- DELETE filter must include `liker_id`, `target_type`, and `target_id` for RLS compliance.

### `personal_bests`
- `id`, `user_id`, `event_name`, `value` (Double), `value_unit` (String), `category` (String), `reps` (Int?, nullable), `is_public` (Bool), `proof_url` (String?, nullable), `logged_at`, `created_at`
- Time-based events: detect via `value_unit` containing "min", "sec", or "s", or ":" in the displayed value string — lower value = better
- All other events: higher value = better
- Used by ProgressViewModel.fetchPersonalBests(userId:) and the new fetchPBsForUsers(userIds:)

### `products` (shared product catalogue — supplement barcode lookup)
- `id` (uuid), `source` (text, CHECK in `au_seed`/`off`/`dsld`/`user`/`peptide_seed`/`ped_seed`/`vision_ocr`/`affiliate_feed`/`tga_artg`), `source_id`, `barcode`, `brand`, `product_name` (not null), `serving_size` (numeric), `serving_units`, `servings_per_container` (int), `dosage_form`, `ingredients_json` (jsonb), `image_url`, `country` (default `'AU'`), `artg_number`, `artg_type`, `affiliate_url`, `verified` (bool, default false), `contributed_by` (uuid → auth.users), `created_at`, `updated_at`
- Unique partial index on `barcode` WHERE `barcode IS NOT NULL` — PostgREST `upsert`/`onConflict` cannot target it; use select-then-insert/update (the `barcode-lookup` Edge Function does this with the service-role key)
- CHECK `no_affiliate_on_restricted`: `affiliate_url` must be NULL when `source` is `peptide_seed`/`ped_seed`
- RLS: `products_select` (read requires `auth.uid() IS NOT NULL`), `products_user_insert`/`products_user_update`/`products_user_delete` (only `source = 'user' AND contributed_by = auth.uid()`). Server-side writes (seeders, Edge Function) use the service-role key (RLS bypass).
- Edge Function `barcode-lookup` (`supabase/functions/barcode-lookup/index.ts`) resolves a barcode via Open Food Facts, caches the row here, returns it. Client query: `from("products").select(...).eq("barcode", value:)`.

### `supplements` (additional columns — supplement expansion P1)
- Beyond the columns listed above, `supplements` also has: `product_id` (uuid → products.id, nullable), `custom_brand` (text), `barcode_scanned` (text), `cycle_pattern` (text), `taper_json` (jsonb). AddSupplementView (and the Quick-Log "scan → add to stack" flow) set `product_id` + `barcode_scanned` when a scanned product is matched; the rest are reserved for later phases. The `Supplement` Swift model decodes `barcode_scanned`.

### `quick_logs` (Quick-Log FAB — freeform / fallback activity log)
- `id` (uuid pk, default `gen_random_uuid()`), `user_id` (uuid → auth.users, not null), `category` (text — currently the lowercased workout type, e.g. `"run"`), `note` (text, nullable — e.g. `"30 min"`), `duration_minutes` (int, nullable), `logged_at` (timestamptz, default `now()`), `created_at` (timestamptz, default `now()`)
- RLS: `quick_logs_own` — `for all using (auth.uid() = user_id)` (owner-only, mirrors `blood_markers`). Inserts run under the user's session, `user_id` must equal the signed-in user (lowercased).
- Written by `QuickLogViewModel.logWorkout` when a workout maps onto neither an existing habit nor a scheduled group session. Workouts that DO match a habit go to `habit_logs` instead; ones with a group session today go to `attendance` ("mark attended").

---

## Relationship / implementation notes
- Use `AppGroup`, not `Group`
- Use `AppSession`, not `Session`
- For nested Supabase relations, use wrapper structs to decode joined results
- Do not revert corrected field names used by AI insights and wellness features
- For V1 `NotificationsView`, use existing tables and view models only — do not add a new notifications table unless explicitly approved
