-- ============================================================
-- F1 follow-up #2: discover Matt's user via foundation_member +
-- email pattern, flip is_premium. Diagnostic notices included
-- so we can see what got matched.
-- ============================================================

do $$
declare
  rec record;
  matt_id uuid;
  matt_email text;
  cnt int := 0;
begin
  raise notice '== Foundation members (id | email | created) ==';
  for rec in
    select p.id, au.email, p.created_at
      from profiles p
      join auth.users au on au.id = p.id
      where p.is_foundation_member = true
      order by p.created_at
  loop
    raise notice '  % | % | %', rec.id, rec.email, rec.created_at;
    cnt := cnt + 1;
    if matt_id is null and (
      rec.email ilike '%matt%' or
      rec.email ilike '%blake%' or
      rec.email ilike '%coast%' or
      rec.email ilike '%ontrack%'
    ) then
      matt_id := rec.id;
      matt_email := rec.email;
    end if;
  end loop;
  raise notice 'Total foundation members: %', cnt;

  if matt_id is not null then
    update profiles
      set is_premium = true,
          premium_since = coalesce(premium_since, now())
      where id = matt_id;
    raise notice 'Set premium=true for Matt: % (%)', matt_email, matt_id;
  else
    raise notice 'No Matt-like email found among foundation members';
  end if;
end $$;
