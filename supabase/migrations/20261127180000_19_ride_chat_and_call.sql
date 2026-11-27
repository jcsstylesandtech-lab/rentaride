-- Chat and call between a rider and their driver, only while they are
-- matched: accepted (driver on the way), driver_arrived, in_progress.

create or replace function public.ride_is_live_for_me(p_ride uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.rides r
    where r.id = p_ride
      and r.status in ('accepted', 'driver_arrived', 'in_progress')
      and (select auth.uid()) in (r.passenger_id, r.driver_id));
$$;

-- Returns the ride's chat, opening it on first use.
create or replace function public.open_ride_chat(p_ride uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if not public.ride_is_live_for_me(p_ride) then
    raise exception 'Chat opens once your driver accepts the trip and closes when it ends'
      using errcode = '42501';
  end if;
  insert into public.conversations (kind, user_id, ride_id)
  values ('ride', (select auth.uid()), p_ride)
  on conflict (ride_id) where kind = 'ride' do nothing;
  select id into v_id from public.conversations where kind = 'ride' and ride_id = p_ride;
  return v_id;
end $$;

-- The other person's phone number, for the call button.
create or replace function public.ride_contact_phone(p_ride uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_phone text;
begin
  if not public.ride_is_live_for_me(p_ride) then
    raise exception 'Calling is available only during your trip' using errcode = '42501';
  end if;
  select p.phone into v_phone
  from public.rides r
  join public.profiles p
    on p.id = case when r.passenger_id = (select auth.uid()) then r.driver_id else r.passenger_id end
  where r.id = p_ride;
  return v_phone;
end $$;

revoke all on function public.ride_is_live_for_me(uuid) from public, anon;
revoke all on function public.open_ride_chat(uuid) from public, anon;
revoke all on function public.ride_contact_phone(uuid) from public, anon;
grant execute on function public.ride_is_live_for_me(uuid) to authenticated;
grant execute on function public.open_ride_chat(uuid) to authenticated;
grant execute on function public.ride_contact_phone(uuid) to authenticated;

-- Ride chats are read-only once the trip is over (history stays visible).
create policy "Ride chat closes after the trip"
  on public.messages as restrictive for insert to authenticated
  with check (
    public.is_admin()
    or not exists (select 1 from public.conversations c
                   where c.id = conversation_id and c.kind = 'ride')
    or exists (select 1 from public.conversations c
               where c.id = conversation_id and c.kind = 'ride' and public.ride_is_live_for_me(c.ride_id)));
