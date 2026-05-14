-- ============================================================
-- F1: Premium Dashboard Schema (idempotent — safe to re-run)
-- ============================================================

-- 1) Profile premium flags
alter table profiles add column if not exists is_premium boolean default false;
alter table profiles add column if not exists premium_since timestamptz;

-- 2) User protocols
create table if not exists user_protocols (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  protocol_type text not null check (protocol_type in (
    'trt','fat_loss','hyrox','muscle_gain','general_health','peptide_protocol','hormonal_optimisation','custom'
  )),
  protocol_name text not null,
  start_date date not null,
  end_date date,
  is_active boolean default true,
  goal text,
  notes text,
  config jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table user_protocols enable row level security;
drop policy if exists "user_protocols_own" on user_protocols;
create policy "user_protocols_own" on user_protocols for all using (auth.uid() = user_id);
create unique index if not exists user_protocols_one_active
  on user_protocols(user_id) where (is_active = true);

-- 3) Dashboard layouts (one row per user)
create table if not exists dashboard_layouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users not null,
  widgets jsonb default '[]'::jsonb,
  theme text default 'dark',
  updated_at timestamptz default now()
);
alter table dashboard_layouts enable row level security;
drop policy if exists "dashboard_layouts_own" on dashboard_layouts;
create policy "dashboard_layouts_own" on dashboard_layouts for all using (auth.uid() = user_id);

-- 4) Supplement partners (public read of active)
create table if not exists supplement_partners (
  id uuid primary key default gen_random_uuid(),
  partner_name text not null,
  partner_logo_url text,
  website_url text,
  is_active boolean default true,
  created_at timestamptz default now()
);
alter table supplement_partners enable row level security;
drop policy if exists "supplement_partners_public_read" on supplement_partners;
create policy "supplement_partners_public_read" on supplement_partners
  for select using (is_active = true);

-- 5) Partner discount codes (public read of active; unique on partner+code)
create table if not exists partner_discount_codes (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid references supplement_partners not null,
  supplement_name_match text[] not null default '{}',
  product_id uuid references products,
  discount_code text not null,
  discount_description text,
  discount_percentage numeric,
  affiliate_url text,
  valid_until date,
  is_active boolean default true,
  created_at timestamptz default now()
);
-- Add unique constraint via index (handles re-runs gracefully)
do $$ begin
  if not exists (select 1 from pg_indexes where indexname = 'partner_discount_codes_partner_code_uniq') then
    create unique index partner_discount_codes_partner_code_uniq
      on partner_discount_codes(partner_id, discount_code);
  end if;
end $$;
alter table partner_discount_codes enable row level security;
drop policy if exists "partner_discount_codes_public_read" on partner_discount_codes;
create policy "partner_discount_codes_public_read" on partner_discount_codes
  for select using (is_active = true);

-- 6) User discount unlocks (per-user reveal tracking)
create table if not exists user_discount_unlocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  discount_id uuid references partner_discount_codes not null,
  unlocked_at timestamptz default now(),
  viewed_at timestamptz,
  clicked_at timestamptz,
  unique(user_id, discount_id)
);
alter table user_discount_unlocks enable row level security;
drop policy if exists "user_discount_unlocks_own" on user_discount_unlocks;
create policy "user_discount_unlocks_own" on user_discount_unlocks for all using (auth.uid() = user_id);

-- 7) Body metrics
create table if not exists body_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  metric_date date default current_date,
  weight_kg numeric,
  body_fat_pct numeric,
  muscle_mass_kg numeric,
  waist_cm numeric,
  chest_cm numeric,
  arm_cm numeric,
  neck_cm numeric,
  notes text,
  source text default 'manual',
  created_at timestamptz default now()
);
alter table body_metrics enable row level security;
drop policy if exists "body_metrics_own" on body_metrics;
create policy "body_metrics_own" on body_metrics for all using (auth.uid() = user_id);

-- 8) Protocol phases (cascade with parent protocol)
create table if not exists protocol_phases (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid references user_protocols(id) on delete cascade not null,
  phase_name text not null,
  week_start int not null,
  week_end int not null,
  description text,
  milestones jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);
alter table protocol_phases enable row level security;
drop policy if exists "protocol_phases_own" on protocol_phases;
create policy "protocol_phases_own" on protocol_phases
  for all using (exists (
    select 1 from user_protocols up
    where up.id = protocol_id and up.user_id = auth.uid()
  ));

-- 9) Health journal
create table if not exists health_journal (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  protocol_id uuid references user_protocols(id),
  entry_date date default current_date,
  week_number int,
  body text not null,
  tag text default 'general',
  created_at timestamptz default now()
);
alter table health_journal enable row level security;
drop policy if exists "health_journal_own" on health_journal;
create policy "health_journal_own" on health_journal for all using (auth.uid() = user_id);

-- Idempotency index for F8 migration (hash of body to allow same date/week with diff text)
create unique index if not exists health_journal_user_date_week_body
  on health_journal(user_id, entry_date, week_number, md5(body));

-- 10) Idempotency index on blood_markers for F6 migration
create unique index if not exists blood_markers_user_marker_collected
  on blood_markers(user_id, marker, collected_at);

-- 11) Seed mock partners (fixed UUIDs for idempotency)
insert into supplement_partners (id, partner_name, website_url, is_active) values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'Optimum Nutrition', 'https://www.optimumnutrition.com', true),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'Bulk',               'https://www.bulk.com',              true),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'Thorne',             'https://www.thorne.com',            true)
on conflict (id) do nothing;

-- 12) Seed discount codes
insert into partner_discount_codes
  (partner_id, supplement_name_match, discount_code, discount_description, discount_percentage, affiliate_url, is_active)
values
  ('11111111-1111-1111-1111-111111111111'::uuid, array['Creatine'],  'ONTRACK10', '10% off creatine',  10, 'https://www.optimumnutrition.com/?ref=ontrack',   true),
  ('22222222-2222-2222-2222-222222222222'::uuid, array['Zinc'],      'ZINC15',    '15% off zinc',      15, 'https://www.bulk.com/zinc?ref=ontrack',           true),
  ('33333333-3333-3333-3333-333333333333'::uuid, array['Magnesium'], 'MAG20',     '20% off magnesium', 20, 'https://www.thorne.com/magnesium?ref=ontrack',    true)
on conflict (partner_id, discount_code) do nothing;
