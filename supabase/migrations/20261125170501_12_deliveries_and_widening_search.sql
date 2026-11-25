-- Applied to Supabase project apebeihmocdomsrhefqs as "12_deliveries_and_widening_search".
-- Deliveries: a ride row carries the service and, for packages, who receives it.
alter table public.rides
  add column service_type public.service_type not null default 'ride',
  add column recipient_name text check (char_length(recipient_name) <= 80),
  add column recipient_phone text check (recipient_phone ~ '^\+234[0-9]{10}$'),
  add column package_size text check (package_size in ('small', 'medium', 'large')),
  add column package_note text check (char_length(package_note) <= 200),
  add constraint package_needs_recipient check (
    service_type = 'ride' or (recipient_name is not null and recipient_phone is not null and package_size is not null)),
  add constraint service_vehicle_match check (
    (service_type = 'ride')
    or (service_type = 'dispatch' and vehicle_class = 'motorcycle' and package_size <> 'large')
    or (service_type = 'delivery' and vehicle_class in ('economy', 'suv')));
create index rides_open_service_idx on public.rides (service_type, requested_at) where status = 'requested';

-- Search area grows while a request waits: 2 km, +1.5 km every 30 s, up to 10 km.
create or replace function public.search_radius_m(p_requested_at timestamptz)
returns integer language sql stable set search_path = '' as $$
  select least(2000 + 1500 * floor(greatest(extract(epoch from (now() - p_requested_at)), 0) / 30)::int, 10000);
$$;

-- A driver may only take work of their own service.
create or replace function public.driver_serves(p_driver uuid, p_ride uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.drivers d join public.rides r on r.id = p_ride
                 where d.id = p_driver and d.service_type = r.service_type);
$$;

-- Requests the calling driver can take: same service, a matching approved
-- vehicle, inside the request's current search area. Includes package details.
create or replace function public.open_jobs(p_radius_m integer default 10000)
returns table (ride_id uuid, service_type public.service_type, vehicle_class public.vehicle_class,
  pricing_mode public.pricing_mode, pickup_address text, pickup_lat double precision, pickup_lng double precision,
  dropoff_address text, distance_m integer, duration_s integer, estimated_fare_kobo bigint, offered_fare_kobo bigint,
  pickup_distance_m double precision, passenger_first_name text, passenger_rating numeric, requested_at timestamptz,
  package_size text, package_note text)
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  my_service public.service_type;
  here extensions.geography;
begin
  select d.service_type into my_service from public.drivers d where d.id = me and d.status = 'approved' and d.is_online;
  if my_service is null then
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
    where r.status = 'requested' and r.passenger_id <> me and r.service_type = my_service
      and r.requested_at > now() - interval '15 minutes'
      and extensions.st_dwithin(r.pickup_location, here,
            least(public.search_radius_m(r.requested_at), greatest(p_radius_m, 500), 15000))
      and exists (select 1 from public.vehicles v where v.driver_id = me and v.is_active
                  and v.review = 'approved' and v.class = r.vehicle_class)
    order by 13 limit 20;
end $$;

-- The older function (used by driver apps not yet updated) gets the same rules.
create or replace function public.open_ride_requests(p_radius_m integer default 5000)
returns table (ride_id uuid, vehicle_class public.vehicle_class, pricing_mode public.pricing_mode,
  pickup_address text, pickup_lat double precision, pickup_lng double precision,
  dropoff_address text, distance_m integer, duration_s integer,
  estimated_fare_kobo bigint, offered_fare_kobo bigint, pickup_distance_m double precision,
  passenger_first_name text, passenger_rating numeric, requested_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select j.ride_id, j.vehicle_class, j.pricing_mode, j.pickup_address, j.pickup_lat, j.pickup_lng,
         j.dropoff_address, j.distance_m, j.duration_s, j.estimated_fare_kobo, j.offered_fare_kobo,
         j.pickup_distance_m, j.passenger_first_name, j.passenger_rating, j.requested_at
  from public.open_jobs(p_radius_m) j;
$$;

create or replace function public.accept_ride(p_ride_id uuid)
returns public.rides language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  r public.rides;
  v uuid;
begin
  select * into r from public.rides where id = p_ride_id for update;
  if r.id is null or r.status <> 'requested' or r.pricing_mode <> 'fixed' or r.passenger_id = me then
    raise exception 'This ride is no longer available' using errcode = 'P0001';
  end if;
  if not public.driver_serves(me, r.id) then
    raise exception 'This request is for a different service' using errcode = 'P0001';
  end if;
  v := public.driver_vehicle_for(me, r.vehicle_class);
  update public.rides set driver_id = me, vehicle_id = v, status = 'accepted',
    agreed_fare_kobo = estimated_fare_kobo, accepted_at = now()
  where id = p_ride_id returning * into r;
  return r;
end $$;

create or replace function public.ride_open_for_offers(p_ride_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rides r where r.id = p_ride_id
    and r.status = 'requested' and r.pricing_mode = 'negotiable'
    and r.passenger_id <> (select auth.uid()))
    and public.driver_serves((select auth.uid()), p_ride_id);
$$;

-- Bikes / cars on the passenger map for one service.
create or replace function public.nearby_service_drivers(
  p_lat double precision, p_lng double precision, p_service public.service_type, p_radius_m integer default 3000)
returns table (driver_ref text, lat double precision, lng double precision,
               heading_deg real, vehicle_class public.vehicle_class)
language sql stable security definer set search_path = '' as $$
  select md5(l.driver_id::text || current_date::text),
         extensions.st_y(l.location::extensions.geometry),
         extensions.st_x(l.location::extensions.geometry),
         l.heading_deg, v.class
  from public.driver_locations l
  join public.drivers d on d.id = l.driver_id and d.status = 'approved' and d.is_online
                       and d.service_type = p_service
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

-- What the passenger's "searching" screen shows: the current search area and
-- how many matching drivers are inside it right now.
create or replace function public.ride_search_status(p_ride_id uuid)
returns table (radius_m integer, drivers_in_range integer, seconds_waiting integer, expires_in_s integer)
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
                              and d.service_type = r.service_type
        where l.updated_at > now() - interval '2 minutes'
          and extensions.st_dwithin(l.location, r.pickup_location, public.search_radius_m(r.requested_at))
          and exists (select 1 from public.vehicles v where v.driver_id = d.id and v.is_active
                      and v.review = 'approved' and v.class = r.vehicle_class)
          and not exists (select 1 from public.rides x where x.driver_id = d.id
                          and x.status in ('accepted', 'driver_arrived', 'in_progress'))),
      extract(epoch from (now() - r.requested_at))::int,
      greatest(900 - extract(epoch from (now() - r.requested_at))::int, 0);
end $$;

revoke execute on function public.open_jobs, public.nearby_service_drivers, public.ride_search_status,
  public.driver_serves, public.search_radius_m from public, anon;
grant execute on function public.open_jobs, public.nearby_service_drivers, public.ride_search_status to authenticated;
revoke execute on function public.driver_serves from authenticated;
