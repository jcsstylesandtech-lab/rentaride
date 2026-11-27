-- Support inbox for the dashboard: one row per thread with the person,
-- last message and unread count, newest activity first. Staff only.

create or replace function public.support_inbox(p_kind public.conversation_kind)
returns table (
  id uuid, kind public.conversation_kind, created_at timestamptz,
  user_id uuid, full_name text, phone text, avatar_url text, role text,
  last_body text, last_at timestamptz, last_from_user boolean, unread integer)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.kind, c.created_at,
         p.id, p.full_name, p.phone, p.avatar_url, p.role::text,
         l.body, l.created_at, l.sender_id = c.user_id,
         (select count(*)::int from public.messages u
           where u.conversation_id = c.id and u.sender_id = c.user_id and u.read_at is null)
  from public.conversations c
  join public.profiles p on p.id = c.user_id
  left join lateral (
    select m.body, m.created_at, m.sender_id from public.messages m
    where m.conversation_id = c.id order by m.created_at desc limit 1) l on true
  where public.is_admin() and c.kind = p_kind
  order by coalesce(l.created_at, c.created_at) desc
  limit 300;
$$;

-- Unanswered messages from riders and drivers, for the top-bar badge.
create or replace function public.unread_support_messages()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_admin() then (
    select count(*)::int from public.messages m
    join public.conversations c on c.id = m.conversation_id
    where c.kind in ('support', 'safety') and m.sender_id = c.user_id and m.read_at is null)
  else 0 end;
$$;

revoke all on function public.support_inbox(public.conversation_kind) from public, anon;
revoke all on function public.unread_support_messages() from public, anon;
grant execute on function public.support_inbox(public.conversation_kind) to authenticated;
grant execute on function public.unread_support_messages() to authenticated;
