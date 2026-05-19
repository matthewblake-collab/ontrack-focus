-- Apple Health → Supabase sync table
-- Stores per-sample HealthKit metrics keyed by user + day + metric_type.

create table if not exists public.health_metrics (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles(id) on delete cascade,
  recorded_at  timestamptz not null,
  metric_type  text        not null,
  value        numeric     not null,
  source       text        default 'apple_health',
  created_at   timestamptz default now(),
  unique (user_id, recorded_at, metric_type)
);

create index if not exists health_metrics_user_recorded_idx
  on public.health_metrics (user_id, recorded_at desc);

create index if not exists health_metrics_user_type_recorded_idx
  on public.health_metrics (user_id, metric_type, recorded_at desc);

alter table public.health_metrics enable row level security;

drop policy if exists "health_metrics select own" on public.health_metrics;
create policy "health_metrics select own"
  on public.health_metrics for select
  using (auth.uid() = user_id);

drop policy if exists "health_metrics insert own" on public.health_metrics;
create policy "health_metrics insert own"
  on public.health_metrics for insert
  with check (auth.uid() = user_id);

drop policy if exists "health_metrics update own" on public.health_metrics;
create policy "health_metrics update own"
  on public.health_metrics for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "health_metrics delete own" on public.health_metrics;
create policy "health_metrics delete own"
  on public.health_metrics for delete
  using (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'health_metrics'
  ) then
    execute 'alter publication supabase_realtime add table public.health_metrics';
  end if;
end $$;
