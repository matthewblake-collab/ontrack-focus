-- Blog post view-counter table + atomic upsert RPC.
-- Article content lives in MDX files in the website repo; this table only
-- tracks per-slug view counts. Anonymous role only has access via the RPC,
-- which is SECURITY DEFINER so it can write without exposing the table.

create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  views integer not null default 0,
  last_viewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.blog_posts enable row level security;

-- Atomic upsert + increment. Returns the new view count.
create or replace function public.increment_blog_view(p_slug text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_views integer;
begin
  if p_slug is null or length(trim(p_slug)) = 0 or length(p_slug) > 200 then
    raise exception 'invalid slug';
  end if;

  insert into public.blog_posts (slug, views, last_viewed_at)
  values (p_slug, 1, now())
  on conflict (slug)
  do update set
    views = public.blog_posts.views + 1,
    last_viewed_at = now()
  returning views into v_views;

  return v_views;
end;
$$;

revoke all on function public.increment_blog_view(text) from public;
grant execute on function public.increment_blog_view(text) to anon, authenticated;
