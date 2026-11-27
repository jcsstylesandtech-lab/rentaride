-- Live support chat: read receipts that work with several staff, live
-- conversation lists on the dashboard, and typing indicators.

-- 1. Opening a thread marks only the *other side's* messages as read.
--    Before, a second staff member opening a thread marked a colleague's
--    reply as read, so the rider's unread badge never showed it.
create or replace function public.mark_conversation_read(p_conversation uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.messages m set read_at = now()
  from public.conversations c
  where c.id = m.conversation_id
    and m.conversation_id = p_conversation
    and m.read_at is null
    and m.sender_id <> (select auth.uid())
    and public.in_conversation(p_conversation)
    and (c.kind = 'ride'
         or c.user_id = (select auth.uid())   -- the rider/driver reads the team's replies
         or m.sender_id = c.user_id);         -- staff read the rider/driver's messages
$$;

-- 2. New conversations appear on the dashboard without a reload.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations') then
    alter publication supabase_realtime add table public.conversations;
  end if;
end $$;

-- 3. Typing indicators travel on private broadcast channels named
--    chat:<conversation id>. Only people in that conversation may join.
create or replace function public.can_use_chat_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_topic ~ '^chat:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.in_conversation(substr(p_topic, 6)::uuid)
    else false
  end;
$$;
revoke all on function public.can_use_chat_topic(text) from public, anon;
grant execute on function public.can_use_chat_topic(text) to authenticated;

create policy "Chat members receive typing"
  on realtime.messages for select to authenticated
  using (realtime.messages.extension = 'broadcast' and public.can_use_chat_topic(realtime.topic()));

create policy "Chat members send typing"
  on realtime.messages for insert to authenticated
  with check (realtime.messages.extension = 'broadcast' and public.can_use_chat_topic(realtime.topic()));
