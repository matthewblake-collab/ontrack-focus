-- Security Hardening — Tier 1 (safe lockdowns, no client behaviour change)
--
-- Phase A audit lived in ~/Desktop/COWORK_BLOCKERS.md. This migration is the
-- safe subset only — no table-grant changes, no SECURITY DEFINER ACL changes.
-- Tier 2 (table + function ACLs) is queued separately pending Matt's sign-off.
--
-- What this changes:
--   1. public.update_updated_at_column — recreated with explicit search_path
--      and locked down. Trigger function only; not callable via REST.
--   2. storage.objects SELECT policies for `avatars` and `group-images` —
--      scoped so anon can no longer list every object. Direct object reads
--      via the public-bucket URL endpoint are unaffected (both buckets are
--      flagged public:true and the public URL path bypasses RLS).
--
-- The Auth setting `password_hibp_enabled` is flipped via Management API,
-- not SQL — applied separately in Phase B.

begin;

-- --------------------------------------------------------------
-- 1. Trigger function: update_updated_at_column
-- --------------------------------------------------------------
create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.update_updated_at_column() from public, anon, authenticated;
-- Triggers run as the trigger-owner (postgres / definer) so no external grant needed.

-- --------------------------------------------------------------
-- 2. Storage bucket SELECT policies
-- --------------------------------------------------------------
-- Drop the open "Anyone can view ..." SELECT policies and replace with
-- scoped versions. Public URL access is unaffected — both buckets remain
-- public:true and the storage.objects RLS path only governs the
-- authenticated/REST list+download endpoints, not the public URL endpoint.

drop policy if exists "Anyone can view avatars" on storage.objects;
drop policy if exists "Anyone can view group images" on storage.objects;

-- Avatars: owner can list/read their own folder. Everyone else relies on
-- the public-bucket URL (which is what iOS uses — getPublicURL only).
create policy "Avatars: owner can list/read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and lower((storage.foldername(name))[1]) = lower((auth.uid())::text)
);

-- Group images: uploader can list/read their own group-image uploads.
-- Upload path convention is `<uploaderUserId>/<groupId>.jpg` (see
-- GroupDetailView.swift:583), so the top-level folder is the uploader's
-- user id, not the group id. Cross-member viewing of group images
-- continues to work via the public URL endpoint (bucket is public:true);
-- the RLS path only governs list/authenticated-download, which now
-- requires owner identity.
create policy "Group images: uploader can list/read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'group-images'
  and lower((storage.foldername(name))[1]) = lower((auth.uid())::text)
);

commit;
