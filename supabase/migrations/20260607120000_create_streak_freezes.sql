-- streak_freezes — records streak-freeze tokens consumed by a user to protect a missed day.
-- target_type: 'habit' (target_id = habits.id) or 'session' (target_id = group_members.id)
-- freeze_date: the day that would break the streak, stored as 'YYYY-MM-DD' text to match app parsing.
-- Applied directly to prod via MCP on 2026-06-07; captured here to sync local migrations with remote.

create table public.streak_freezes (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users,
  target_type text        not null,
  target_id   uuid        not null,
  freeze_date text        not null,
  created_at  timestamptz not null default now(),
  unique (user_id, target_type, target_id, freeze_date)
);

alter table public.streak_freezes enable row level security;

create policy "streak_freezes_own" on public.streak_freezes
  for all using (auth.uid() = user_id);
