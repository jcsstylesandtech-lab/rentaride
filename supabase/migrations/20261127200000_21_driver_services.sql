-- Drivers choose which jobs they take: rides, dispatch, delivery (any mix),
-- instead of being locked to the single service picked at sign-up. A job
-- still needs an approved vehicle of the right class (motorcycle for
-- dispatch, car or van for delivery), which open_jobs already checks.

alter table public.drivers
  add column if not exists services public.service_type[] not null default '{ride}';
update public.drivers set services = array[service_type] where services = '{ride}' and service_type <> 'ride';
alter table public.drivers drop constraint if exists drivers_services_not_empty;
alter table public.drivers add constraint drivers_services_not_empty check (cardinality(services) >= 1);

-- While applying, the chosen service is the job list.
create or replace function public.sync_driver_services()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' or (new.service_type is distinct from old.service_type and new.status <> 'approved') then
    new.services := array[new.service_type];
  end if;
  return new;
end $$;
drop trigger if exists drivers_sync_services on public.drivers;
create trigger drivers_sync_services before insert or update of service_type on public.drivers
  for each row execute function public.sync_driver_services();

create or replace function public.driver_serves(p_driver uuid, p_ride uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.drivers d join public.rides r on r.id = p_ride
                 where d.id = p_driver and r.service_type = any (d.services));
$$;

create or replace function public.nearby_service_drivers(p_lat double precision, p_lng double precision,
  p_service public.service_type, p_radius_m integer default 3000)
returns table(driver_ref text, lat double precision, lng double precision, heading_deg real, vehicle_class public.vehicle_class)
language sql stable security definer set search_path = '' as $$
  select md5(l.driver_id::text || current_date::text),
         extensions.st_y(l.location::extensions.geometry),
         extensions.st_x(l.location::extensions.geometry),
         l.heading_deg, v.class
  from public.driver_locations l
  join public.drivers d on d.id = l.driver_id and d.status = 'approved' and d.is_online
                       and p_service = any (d.services)
  join lateral (select class from public.vehicles
                where driver_id = d.id and is_active and review = 'approved' limit 1) v on true
  where l.updated_at > now() - interval '2 minutes'
    and extensions.st_dwithin(l.location,
          extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
          least(greatest(p_radius_m, 100), 10000))
    and not exists (select 1 from public.rides r where r.driver_id = d.id
                    and r.status in ('accepted', 'driver_arrived', 'in_progress'))
  limit 30;
$$;

create or replace function public.ride_search_status(p_ride_id uuid)
returns table(radius_m integer, drivers_in_range integer, seconds_waiting integer, expires_in_s integer)
language plpgsql stable security definer set search_path = '' as $$
declare r public.rides;
begin
  select * into r from public.rides where id = p_ride_id;
  if r.id is null or r.passenger_id <> (select auth.uid()) then
    raise exception 'Not your ride' using errcode = '42501';
  end if;
  return query
    select public.search_radius_m(r.requested_at),
      (select count(*)::int from public.driver_locations l
         join public.drivers d on d.id = l.driver_id and d.status = 'approved' and d.is_online
                              and r.service_type = any (d.services)
        where l.updated_at > now() - interval '2 minutes'
          and extensions.st_dwithin(l.location, r.pickup_location, public.search_radius_m(r.requested_at))
          and exists (select 1 from public.vehicles v where v.driver_id = d.id and v.is_active
                      and v.review = 'approved' and v.class = r.vehicle_class)
          and not exists (select 1 from public.rides x where x.driver_id = d.id
                          and x.status in ('accepted', 'driver_arrived', 'in_progress'))),
      extract(epoch from (now() - r.requested_at))::int,
      greatest(900 - extract(epoch from (now() - r.requested_at))::int, 0);
end $$;

create or replace function public.open_jobs(p_radius_m integer default 10000)
returns table(ride_id uuid, service_type public.service_type, vehicle_class public.vehicle_class,
  pricing_mode public.pricing_mode, pickup_address text, pickup_lat double precision, pickup_lng double precision,
  dropoff_address text, distance_m integer, duration_s integer, estimated_fare_kobo bigint, offered_fare_kobo bigint,
  pickup_distance_m double precision, passenger_first_name text, passenger_rating numeric,
  requested_at timestamptz, package_size text, package_note text)
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  my_services public.service_type[];
  here extensions.geography;
begin
  select d.services into my_services from public.drivers d where d.id = me and d.status = 'approved' and d.is_online;
  if my_services is null then
    raise exception 'Only approved drivers who are online can see ride requests' using errcode = '42501';
  end if;
  select location into here from public.driver_locations where driver_id = me;
  if here is null then return; end if;
  return query
    select r.id, r.service_type, r.vehicle_class, r.pricing_mode, r.pickup_address,
      extensions.st_y(r.pickup_location::extensions.geometry),
      extensions.st_x(r.pickup_location::extensions.geometry),
      r.dropoff_address, r.distance_m, r.duration_s, r.estimated_fare_kobo, r.offered_fare_kobo,
      extensions.st_distance(r.pickup_location, here),
      split_part(p.full_name, ' ', 1), p.rating_avg, r.requested_at, r.package_size, r.package_note
    from public.rides r join public.profiles p on p.id = r.passenger_id
    where r.status = 'requested' and r.passenger_id <> me and r.service_type = any (my_services)
      and r.requested_at > now() - interval '15 minutes'
      and extensions.st_dwithin(r.pickup_location, here,
            least(public.search_radius_m(r.requested_at), greatest(p_radius_m, 500), 15000))
      and exists (select 1 from public.vehicles v where v.driver_id = me and v.is_active
                  and v.review = 'approved' and v.class = r.vehicle_class)
    order by 13 limit 20;
end $$;
