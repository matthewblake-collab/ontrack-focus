-- Server-side push: AFTER triggers on the 7 event tables.
-- All forward the row to public.notify_push_dispatcher(); routing/recipient
-- resolution happens in the push-dispatcher Edge Function.
--
-- NOTE: these tables live in the remote DB. Confirm column names against the
-- remote schema before `supabase db push` (WHEN clauses reference
-- friendships.status, habit_members.status/invited_by/user_id).

drop trigger if exists push_friend_request_insert on public.friendships;
create trigger push_friend_request_insert
  after insert on public.friendships
  for each row when (new.status = 'pending')
  execute function public.notify_push_dispatcher();

drop trigger if exists push_friend_request_accept on public.friendships;
create trigger push_friend_request_accept
  after update on public.friendships
  for each row when (old.status = 'pending' and new.status = 'accepted')
  execute function public.notify_push_dispatcher();

drop trigger if exists push_rsvp on public.rsvps;
create trigger push_rsvp
  after insert or update on public.rsvps
  for each row execute function public.notify_push_dispatcher();

drop trigger if exists push_group_message on public.group_messages;
create trigger push_group_message
  after insert on public.group_messages
  for each row execute function public.notify_push_dispatcher();

drop trigger if exists push_habit_invite on public.habit_members;
create trigger push_habit_invite
  after insert on public.habit_members
  for each row when (new.status = 'pending' and new.invited_by is distinct from new.user_id)
  execute function public.notify_push_dispatcher();

drop trigger if exists push_feed_like on public.feed_likes;
create trigger push_feed_like
  after insert on public.feed_likes
  for each row execute function public.notify_push_dispatcher();

drop trigger if exists push_session_join on public.attendance;
create trigger push_session_join
  after insert on public.attendance
  for each row execute function public.notify_push_dispatcher();
