ALTER TABLE public.streak_freezes
  ADD CONSTRAINT chk_target_type
  CHECK (target_type IN ('habit', 'session'));

ALTER TABLE public.streak_freezes
  ADD CONSTRAINT chk_freeze_date_not_future
  CHECK (freeze_date::date <= current_date + 1);
