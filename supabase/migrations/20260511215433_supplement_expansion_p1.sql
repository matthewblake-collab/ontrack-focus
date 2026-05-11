-- Products table (shared product catalogue)
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('au_seed','off','dsld','user','peptide_seed','ped_seed','vision_ocr','affiliate_feed','tga_artg')),
  source_id text,
  barcode text,
  brand text,
  product_name text not null,
  serving_size numeric,
  serving_units text,
  servings_per_container int,
  dosage_form text,
  ingredients_json jsonb,
  image_url text,
  country text default 'AU',
  artg_number text,
  artg_type text,
  affiliate_url text,
  verified boolean default false,
  contributed_by uuid references auth.users,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint no_affiliate_on_restricted check (
    (source not in ('peptide_seed','ped_seed')) or affiliate_url is null
  )
);

create unique index if not exists products_barcode_idx on products (barcode) where barcode is not null;
create index if not exists products_search_idx on products using gin (to_tsvector('english', coalesce(brand,'') || ' ' || product_name));

-- RLS on products: anyone can read, only service role can write
alter table products enable row level security;
create policy "products_select" on products for select using (true);

-- Blood markers table (personal lab results log)
create table if not exists blood_markers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  collected_at timestamptz not null,
  marker text not null,
  value numeric not null,
  units text not null,
  reference_low numeric,
  reference_high numeric,
  lab text,
  notes text,
  created_at timestamptz default now()
);

alter table blood_markers enable row level security;
create policy "blood_markers_own" on blood_markers for all using (auth.uid() = user_id);

-- New columns on supplements
alter table supplements
  add column if not exists product_id uuid references products(id),
  add column if not exists custom_brand text,
  add column if not exists barcode_scanned text,
  add column if not exists cycle_pattern text,
  add column if not exists taper_json jsonb;
