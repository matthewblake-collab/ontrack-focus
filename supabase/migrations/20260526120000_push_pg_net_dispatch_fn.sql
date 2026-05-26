-- Server-side push: enable pg_net + Vault, and define the webhook dispatch fn.
-- The fn forwards the changed row to the push-dispatcher Edge Function.
--
-- REQUIRED OUT-OF-BAND (never commit the key): after deploy, run once in the
-- SQL editor / `supabase db` against the project:
--   select vault.create_secret(
--     'https://wqkisslixduowewuaiae.supabase.co/functions/v1/push-dispatcher',
--     'push_dispatcher_url');
--   select vault.create_secret('<SERVICE_ROLE_KEY>', 'push_service_key');
-- Until both secrets exist, notify_push_dispatcher() is a safe no-op.

create extension if not exists pg_net;
create extension if not exists supabase_vault;

create or replace function public.notify_push_dispatcher()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net, extensions
as $$
declare
  v_url text;
  v_key text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_dispatcher_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'push_service_key';

  -- Secrets not configured yet → no-op (do not block the originating write).
  if v_url is null or v_key is null then
    return null;
  end if;

  perform net.http_post(
    url := v_url,
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', to_jsonb(old)
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    timeout_milliseconds := 5000
  );

  return null; -- AFTER trigger; return value ignored
end;
$$;
