-- Applied to Supabase project apebeihmocdomsrhefqs as "13_app_control_and_notifications".
-- App control: one row of switches staff change from the dashboard; the apps
-- read it live.
create table public.app_settings (
  id smallint primary key default 1 check (id = 1),
  rides_enabled boolean not null default true,
  dispatch_enabled boolean not null default true,
  delivery_enabled boolean not null default true,
  passenger_maintenance boolean not null default false,
  driver_maintenance boolean not null default false,
  maintenance_message text not null default 'We are making Rent A Ride better. Please check back shortly.'
    check (char_length(maintenance_message) <= 300),
  passenger_announcement text check (char_length(passenger_announcement) <= 300),
  driver_announcement text check (char_length(driver_announcement) <= 300),
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now()
);
insert into public.app_settings default values;
create trigger app_settings_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();
alter table public.app_settings enable row level security;
create policy "Everyone reads app settings" on public.app_settings for select to anon, authenticated using (true);
create policy "Operations change app settings" on public.app_settings for update to authenticated
  using (public.has_staff_role('{operations}')) with check (public.has_staff_role('{operations}'));
alter publication supabase_realtime add table public.app_settings;

-- New requests are refused while a service is switched off or the passenger app is in maintenance.
create or replace function public.guard_service_open()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s public.app_settings;
begin
  select * into s from public.app_settings where id = 1;
  if s.passenger_maintenance then
    raise exception '%', s.maintenance_message using errcode = 'P0001';
  end if;
  if (new.service_type = 'ride' and not s.rides_enabled)
     or (new.service_type = 'dispatch' and not s.dispatch_enabled)
     or (new.service_type = 'delivery' and not s.delivery_enabled) then
    raise exception '% is paused right now. Please try again later.',
      case new.service_type when 'ride' then 'Booking rides' when 'dispatch' then 'Dispatch' else 'Delivery' end
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger rides_service_open before insert on public.rides
  for each row execute function public.guard_service_open();

-- Broadcast messages from the dashboard. Each one becomes a notification per recipient.
create type public.broadcast_audience as enum
  ('everyone', 'passengers', 'drivers', 'ride_drivers', 'dispatch_riders', 'delivery_drivers', 'one_person');
create table public.broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 120),
  body text not null default '' check (char_length(body) <= 500),
  audience public.broadcast_audience not null,
  target_user uuid references public.profiles (id),
  recipients integer not null default 0,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);
create index broadcasts_created_idx on public.broadcasts (created_at desc);
alter table public.broadcasts enable row level security;
create policy "Staff read broadcasts" on public.broadcasts for select to authenticated using (public.is_admin());

create or replace function public.send_broadcast(
  p_title text, p_body text, p_audience public.broadcast_audience, p_user uuid default null)
returns public.broadcasts language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  b public.broadcasts;
  n integer;
begin
  if not public.has_staff_role('{operations,support}') then
    raise exception 'Only operations or support staff can send notifications' using errcode = '42501';
  end if;
  if p_audience = 'one_person' and p_user is null then
    raise exception 'Choose who to send it to' using errcode = 'P0001';
  end if;
  insert into public.broadcasts (title, body, audience, target_user, created_by)
  values (trim(p_title), coalesce(trim(p_body), ''), p_audience,
          case when p_audience = 'one_person' then p_user end, me)
  returning * into b;

  insert into public.notifications (user_id, title, body, data)
  select p.id, b.title, b.body, jsonb_build_object('kind', 'broadcast', 'broadcast_id', b.id)
  from public.profiles p
  left join public.drivers d on d.id = p.id
  where p.status = 'active' and case p_audience
    when 'one_person' then p.id = p_user
    when 'everyone' then p.role in ('passenger', 'driver')
    when 'passengers' then p.role = 'passenger'
    when 'drivers' then d.id is not null
    when 'ride_drivers' then d.service_type = 'ride'
    when 'dispatch_riders' then d.service_type = 'dispatch'
    when 'delivery_drivers' then d.service_type = 'delivery'
  end;
  get diagnostics n = row_count;
  update public.broadcasts set recipients = n where id = b.id returning * into b;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (me, 'notification.broadcast', 'broadcasts', b.id::text,
          jsonb_build_object('audience', p_audience, 'recipients', n, 'title', b.title));
  return b;
end $$;

-- Trip updates become notifications too, so people hear about them even
-- when they are on another screen.
create or replace function public.notify_ride_status()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  courier text := case new.service_type when 'dispatch' then 'rider' else 'driver' end;
  thing text := case when new.service_type = 'ride' then 'ride' else 'delivery' end;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status = 'accepted' then
    insert into public.notifications (user_id, title, body, data) values (new.passenger_id,
      'Your ' || courier || ' is on the way', 'Tap to follow your ' || thing || ' live.',
      jsonb_build_object('kind', 'ride', 'ride_id', new.id));
  elsif new.status = 'driver_arrived' then
    insert into public.notifications (user_id, title, body, data) values (new.passenger_id,
      'Your ' || courier || ' has arrived', 'Meet them at the pickup point.',
      jsonb_build_object('kind', 'ride', 'ride_id', new.id));
  elsif new.status = 'completed' then
    insert into public.notifications (user_id, title, body, data) values (new.passenger_id,
      case when thing = 'ride' then 'You have arrived' else 'Package delivered' end,
      'Thanks for using Rent A Ride. Tap to rate your ' || courier || '.',
      jsonb_build_object('kind', 'ride', 'ride_id', new.id));
  elsif new.status = 'cancelled' then
    if new.cancelled_by = new.driver_id then
      insert into public.notifications (user_id, title, body, data) values (new.passenger_id,
        'Your ' || courier || ' cancelled', coalesce(new.cancel_reason, 'Please request again.'),
        jsonb_build_object('kind', 'ride', 'ride_id', new.id));
    elsif new.driver_id is not null and new.cancelled_by = new.passenger_id then
      insert into public.notifications (user_id, title, body, data) values (new.driver_id,
        'Trip cancelled by the customer', coalesce(new.cancel_reason, ''),
        jsonb_build_object('kind', 'ride', 'ride_id', new.id));
    end if;
  end if;
  return new;
end $$;
create trigger rides_notify_status after update of status on public.rides
  for each row execute function public.notify_ride_status();

revoke execute on function public.send_broadcast from public, anon;
grant execute on function public.send_broadcast to authenticated;
revoke execute on function public.guard_service_open, public.notify_ride_status from public, anon, authenticated;
