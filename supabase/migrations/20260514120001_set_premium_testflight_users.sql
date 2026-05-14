-- ============================================================
-- F1 follow-up: flip is_premium for Matt (and Luke once email known).
-- Safe to re-run. Skips silently if user not found.
-- ============================================================

do $$
declare
  email_candidate text;
  uid uuid;
begin
  -- Try known Matt emails
  for email_candidate in select unnest(array[
    'matthewblake@coastandcountryenergy.com.au',
    'matthewblake@ontrack-focus.com',
    'matt@blake.email'
  ]) loop
    select id into uid from auth.users where lower(email) = lower(email_candidate) limit 1;
    if uid is not null then
      update profiles
        set is_premium = true,
            premium_since = coalesce(premium_since, now())
        where id = uid;
      raise notice 'Set premium for Matt: % (%)', email_candidate, uid;
      exit;
    end if;
  end loop;

  if uid is null then
    raise notice 'Matt not found by any known email — manual UPDATE required';
  end if;
end $$;

-- Luke's premium flag deferred until his email is provided.
-- To set manually:
--   update profiles set is_premium=true, premium_since=now()
--     where id = (select id from auth.users where lower(email) = lower('<luke-email>'));
