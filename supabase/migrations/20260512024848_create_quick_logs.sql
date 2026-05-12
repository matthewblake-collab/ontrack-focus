-- quick_logs — lightweight freeform/fallback activity log used by the Quick-Log FAB.
-- Currently the home for "session/workout completed" entries that don't map onto an
-- existing habit or a scheduled group session.

create table if not exists quick_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  category text,
  note text,
  duration_minutes int,
  logged_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table quick_logs enable row level security;

create policy "quick_logs_own" on quick_logs
  for all using (auth.uid() = user_id);
