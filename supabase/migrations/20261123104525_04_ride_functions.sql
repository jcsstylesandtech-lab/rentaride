-- Applied to Supabase project apebeihmocdomsrhefqs as "04_ride_functions".
-- Cars on the passenger map: position and heading only, never identity.
create or replace function public.nearby_drivers(
  p_lat double precision, p_lng double precision,
  p_radius_m integer default 3000, p_class public.vehicle_class default null)
returns table (driver_ref text, lat double precision, lng double precision,
               heading_deg real, vehicle_class public.vehicle_class)
language sql stable security definer set search_path = '' as $$
  select md5(l.driver_id::text || current_date::text),
         extensions.st_y(l.location::extensions.geometry),
         extensions.st_x(l.location::extensions.geometry),
         l.heading_deg, v.class
  from public.driver_locations l
  join public.drivers d on d.id = l.driver_id and d.status = 'approved' and d.is_online
  join lateral (select class from public.vehicles
                where driver_id = d.id and is_active and review = 'approved'
                  and (p_class is null or class = p_class) limit 1) v on true
  where l.updated_at > now() - interval '2 minutes'
    and extensions.st_dwithin(l.location,
          extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography,
          least(greatest(p_radius_m, 100), 10000))
    and not exists (select 1 from public.rides r where r.driver_id = d.id
                    and r.status in ('accepted', 'driver_arrived', 'in_progress'))
  limit 30;
$$;

-- Open requests near the calling driver (approved and online).
create or replace function public.open_ride_requests(p_radius_m integer default 5000)
returns table (ride_id uuid, vehicle_class public.vehicle_class, pricing_mode public.pricing_mode,
  pickup_address text, pickup_lat double precision, pickup_lng double precision,
  dropoff_address text, distance_m integer, duration_s integer,
  estimated_fare_kobo bigint, offered_fare_kobo bigint, pickup_distance_m double precision,
  passenger_first_name text, passenger_rating numeric, requested_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  here extensions.geography;
begin
  if not exists (select 1 from public.drivers where id = me and status = 'approved' and is_online) then
    raise exception 'Only approved drivers who are online can see ride requests' using errcode = '42501';
  end if;
  select location into here from public.driver_locations where driver_id = me;
  if here is null then return; end if;
  return query
    select r.id, r.vehicle_class, r.pricing_mode, r.pickup_address,
      extensions.st_y(r.pickup_location::extensions.geometry),
      extensions.st_x(r.pickup_location::extensions.geometry),
      r.dropoff_address, r.distance_m, r.duration_s, r.estimated_fare_kobo, r.offered_fare_kobo,
      extensions.st_distance(r.pickup_location, here),
      split_part(p.full_name, ' ', 1), p.rating_avg, r.requested_at
    from public.rides r join public.profiles p on p.id = r.passenger_id
    where r.status = 'requested' and r.passenger_id <> me
      and r.requested_at > now() - interval '15 minutes'
      and extensions.st_dwithin(r.pickup_location, here, least(greatest(p_radius_m, 500), 15000))
      and exists (select 1 from public.vehicles v where v.driver_id = me and v.is_active
                  and v.review = 'approved' and v.class = r.vehicle_class)
    order by 12 limit 20;
end $$;

-- Shared checks for a driver taking a ride; returns the vehicle to use.
create or replace function public.driver_vehicle_for(p_driver uuid, p_class public.vehicle_class)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v uuid;
begin
  if not exists (select 1 from public.drivers where id = p_driver and status = 'approved' and is_online) then
    raise exception 'Driver must be approved and online' using errcode = '42501';
  end if;
  if exists (select 1 from public.rides where driver_id = p_driver
             and status in ('accepted', 'driver_arrived', 'in_progress')) then
    raise exception 'Finish your current trip first' using errcode = 'P0001';
  end if;
  select id into v from public.vehicles where driver_id = p_driver and is_active
    and review = 'approved' and class = p_class limit 1;
  if v is null then
    raise exception 'No approved vehicle for this ride type' using errcode = 'P0001';
  end if;
  return v;
end $$;

-- Driver accepts a fixed-fare request (first driver wins).
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
  v := public.driver_vehicle_for(me, r.vehicle_class);
  update public.rides set driver_id = me, vehicle_id = v, status = 'accepted',
    agreed_fare_kobo = estimated_fare_kobo, accepted_at = now()
  where id = p_ride_id returning * into r;
  return r;
end $$;

-- Passenger picks a driver's offer on a negotiable ride.
create or replace function public.accept_offer(p_offer_id uuid)
returns public.rides language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  o public.fare_offers;
  r public.rides;
  v uuid;
begin
  select * into o from public.fare_offers where id = p_offer_id for update;
  if o.id is null or o.status <> 'pending' then
    raise exception 'This offer is no longer available' using errcode = 'P0001';
  end if;
  select * into r from public.rides where id = o.ride_id for update;
  if r.passenger_id <> me then
    raise exception 'Not your ride' using errcode = '42501';
  end if;
  if r.status <> 'requested' then
    raise exception 'This ride already has a driver' using errcode = 'P0001';
  end if;
  v := public.driver_vehicle_for(o.driver_id, r.vehicle_class);
  update public.fare_offers set status = 'accepted', responded_at = now() where id = o.id;
  update public.fare_offers set status = 'declined', responded_at = now()
    where ride_id = r.id and id <> o.id and status = 'pending';
  update public.rides set driver_id = o.driver_id, vehicle_id = v, status = 'accepted',
    agreed_fare_kobo = o.amount_kobo, accepted_at = now()
  where id = r.id returning * into r;
  return r;
end $$;

-- Assigned driver moves the trip forward: arrived → in progress → completed.
create or replace function public.advance_ride(p_ride_id uuid, p_status public.ride_status)
returns public.rides language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  r public.rides;
begin
  select * into r from public.rides where id = p_ride_id for update;
  if r.id is null or r.driver_id is distinct from me then
    raise exception 'Not your trip' using errcode = '42501';
  end if;
  if not ((r.status = 'accepted' and p_status = 'driver_arrived')
       or (r.status = 'driver_arrived' and p_status = 'in_progress')
       or (r.status = 'in_progress' and p_status = 'completed')) then
    raise exception 'Cannot go from % to %', r.status, p_status using errcode = 'P0001';
  end if;
  update public.rides set status = p_status,
    arrived_at = case when p_status = 'driver_arrived' then now() else arrived_at end,
    started_at = case when p_status = 'in_progress' then now() else started_at end,
    completed_at = case when p_status = 'completed' then now() else completed_at end,
    final_fare_kobo = case when p_status = 'completed' then agreed_fare_kobo else final_fare_kobo end
  where id = p_ride_id returning * into r;
  return r;
end $$;

-- Passenger or assigned driver cancels before the trip starts.
create or replace function public.cancel_ride(p_ride_id uuid, p_reason text default null)
returns public.rides language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  r public.rides;
begin
  select * into r from public.rides where id = p_ride_id for update;
  if r.id is null or (r.passenger_id <> me and r.driver_id is distinct from me) then
    raise exception 'Not your ride' using errcode = '42501';
  end if;
  if r.status not in ('requested', 'accepted', 'driver_arrived') then
    raise exception 'This ride can no longer be cancelled' using errcode = 'P0001';
  end if;
  update public.fare_offers set status = 'expired', responded_at = now()
    where ride_id = r.id and status = 'pending';
  update public.rides set status = 'cancelled', cancelled_by = me, cancelled_at = now(),
    cancel_reason = left(p_reason, 300)
  where id = p_ride_id returning * into r;
  return r;
end $$;

-- Driver withdraws their own pending offer.
create or replace function public.withdraw_offer(p_offer_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.fare_offers set status = 'withdrawn', responded_at = now()
  where id = p_offer_id and driver_id = (select auth.uid()) and status = 'pending';
$$;

-- What each side of an active or past ride may see about the other:
-- name, photo, rating and vehicle — never the phone number.
create or replace function public.ride_party(p_ride_id uuid)
returns table (passenger_name text, passenger_avatar text, passenger_rating numeric,
  driver_name text, driver_avatar text, driver_rating numeric,
  vehicle_make text, vehicle_model text, vehicle_colour text, plate_number text,
  vehicle_class public.vehicle_class)
language sql stable security definer set search_path = '' as $$
  select split_part(pp.full_name, ' ', 1), pp.avatar_url, pp.rating_avg,
         dp.full_name, dp.avatar_url, dp.rating_avg,
         v.make, v.model, v.colour, v.plate_number, v.class
  from public.rides r
  join public.profiles pp on pp.id = r.passenger_id
  left join public.profiles dp on dp.id = r.driver_id
  left join public.vehicles v on v.id = r.vehicle_id
  where r.id = p_ride_id
    and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid()) or public.is_admin());
$$;

-- Only signed-in users may call these; helpers stay internal.
revoke execute on function public.nearby_drivers, public.open_ride_requests, public.accept_ride,
  public.accept_offer, public.advance_ride, public.cancel_ride, public.withdraw_offer,
  public.ride_party, public.driver_vehicle_for, public.is_admin from public, anon;
grant execute on function public.nearby_drivers, public.open_ride_requests, public.accept_ride,
  public.accept_offer, public.advance_ride, public.cancel_ride, public.withdraw_offer,
  public.ride_party, public.is_admin to authenticated;
revoke execute on function public.driver_vehicle_for from authenticated;
revoke execute on function public.handle_new_user, public.log_ride_status, public.refresh_rating
  from public, anon, authenticated;
