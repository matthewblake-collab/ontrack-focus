-- ============================================================
-- F12: Realtime publications + updated_at triggers
-- Idempotent — safe to re-run.
-- ============================================================

-- 1) Generic updated_at trigger function
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- 2) Apply trigger to tables with an updated_at column
drop trigger if exists user_protocols_updated_at on public.user_protocols;
create trigger user_protocols_updated_at
  before update on public.user_protocols
  for each row execute function public.set_updated_at();

drop trigger if exists dashboard_layouts_updated_at on public.dashboard_layouts;
create trigger dashboard_layouts_updated_at
  before update on public.dashboard_layouts
  for each row execute function public.set_updated_at();

-- 3) Ensure supabase_realtime publication exists, then add target tables
do $$
declare
  pub_name text := 'supabase_realtime';
  tbl text;
  realtime_tables text[] := array[
    'daily_checkins',
    'supplements',
    'supplement_logs',
    'user_protocols',
    'body_metrics',
    'health_journal',
    'blood_markers',
    'user_discount_unlocks'
  ];
  added int := 0;
  skipped int := 0;
begin
  if not exists (select 1 from pg_publication where pubname = pub_name) then
    create publication supabase_realtime;
    raise notice 'Created publication %', pub_name;
  end if;

  foreach tbl in array realtime_tables loop
    if exists (
      select 1 from pg_publication_tables
      where pubname = pub_name and schemaname = 'public' and tablename = tbl
    ) then
      skipped := skipped + 1;
    else
      execute format('alter publication %I add table public.%I', pub_name, tbl);
      added := added + 1;
      raise notice 'Added % to publication', tbl;
    end if;
  end loop;

  raise notice 'Realtime publication audit: % added, % already in', added, skipped;
end $$;

-- 4) REPLICA IDENTITY FULL on tables we observe via UPDATE/DELETE events.
--    Default is DEFAULT (PK only) — switching to FULL ensures the full
--    old/new row reaches subscribers. Mild WAL overhead, low-volume
--    tables only.
alter table public.supplements      replica identity full;
alter table public.daily_checkins   replica identity full;
alter table public.health_journal   replica identity full;
alter table public.user_protocols   replica identity full;
alter table public.blood_markers    replica identity full;
alter table public.body_metrics     replica identity full;
alter table public.user_discount_unlocks replica identity full;

-- 5) Diagnostic — report publication membership at end of migration
do $$
declare
  rec record;
begin
  raise notice '== supabase_realtime publication members ==';
  for rec in
    select schemaname, tablename
      from pg_publication_tables
      where pubname = 'supabase_realtime'
      order by schemaname, tablename
  loop
    raise notice '  %.%', rec.schemaname, rec.tablename;
  end loop;
end $$;
