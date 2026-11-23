-- Applied to Supabase project apebeihmocdomsrhefqs as "03_rides_offers_ratings".
create type public.pricing_mode as enum ('fixed', 'negotiable');
create type public.ride_status as enum ('requested', 'accepted', 'driver_arrived', 'in_progress', 'completed', 'cancelled', 'expired');
create type public.payment_method as enum ('cash', 'card', 'wallet');
create type public.offer_status as enum ('pending', 'accepted', 'declined', 'withdrawn', 'expired');

-- Money is stored in kobo (₦1 = 100 kobo) as integers.
create table public.rides (
  id uuid primary key default gen_random_uuid(),
  passenger_id uuid not null references public.profiles (id),
  driver_id uuid references public.drivers (id),
  vehicle_id uuid references public.vehicles (id),
  vehicle_class public.vehicle_class not null default 'economy',
  pricing_mode public.pricing_mode not null default 'fixed',
  status public.ride_status not null default 'requested',
  pickup_location extensions.geography (point, 4326) not null,
  pickup_address text not null check (char_length(pickup_address) <= 250),
  dropoff_location extensions.geography (point, 4326) not null,
  dropoff_address text not null check (char_length(dropoff_address) <= 250),
  distance_m integer check (distance_m >= 0),
  duration_s integer check (duration_s >= 0),
  estimated_fare_kobo bigint not null check (estimated_fare_kobo > 0),
  offered_fare_kobo bigint check (offered_fare_kobo > 0),
  agreed_fare_kobo bigint check (agreed_fare_kobo > 0),
  final_fare_kobo bigint check (final_fare_kobo >= 0),
  payment_method public.payment_method not null default 'cash',
  cancelled_by uuid references public.profiles (id),
  cancel_reason text check (char_length(cancel_reason) <= 300),
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint negotiable_needs_offer check (pricing_mode = 'fixed' or offered_fare_kobo is not null),
  constraint driver_not_passenger check (driver_id is null or driver_id <> passenger_id)
);
create index rides_passenger_idx on public.rides (passenger_id, requested_at desc);
create index rides_driver_idx on public.rides (driver_id, requested_at desc);
create index rides_open_idx on public.rides using gist (pickup_location) where status = 'requested';
create trigger rides_updated_at before update on public.rides
  for each row execute function public.set_updated_at();

-- Driver counter-offers on negotiable rides.
create table public.fare_offers (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides (id) on delete cascade,
  driver_id uuid not null references public.drivers (id),
  amount_kobo bigint not null check (amount_kobo > 0),
  eta_minutes smallint check (eta_minutes between 0 and 120),
  status public.offer_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (ride_id, driver_id)
);
create index fare_offers_ride_idx on public.fare_offers (ride_id);

-- Every status change, for the trip timeline and disputes.
create table public.ride_events (
  id bigint generated always as identity primary key,
  ride_id uuid not null references public.rides (id) on delete cascade,
  status public.ride_status not null,
  actor_id uuid references public.profiles (id),
  created_at timestamptz not null default now()
);
create index ride_events_ride_idx on public.ride_events (ride_id, created_at);

create or replace function public.log_ride_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.ride_events (ride_id, status, actor_id)
    values (new.id, new.status, (select auth.uid()));
  end if;
  return new;
end $$;
create trigger rides_log_status after insert or update on public.rides
  for each row execute function public.log_ride_status();

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides (id) on delete cascade,
  rater_id uuid not null references public.profiles (id),
  ratee_id uuid not null references public.profiles (id),
  stars smallint not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  unique (ride_id, rater_id)
);
create index ratings_ratee_idx on public.ratings (ratee_id);

create or replace function public.refresh_rating()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles p set
    rating_avg = coalesce((select round(avg(stars)::numeric, 2) from public.ratings where ratee_id = new.ratee_id), 5),
    rating_count = (select count(*) from public.ratings where ratee_id = new.ratee_id)
  where p.id = new.ratee_id;
  return new;
end $$;
create trigger ratings_refresh after insert on public.ratings
  for each row execute function public.refresh_rating();

-- Row level security: ride changes go through the functions below.
alter table public.rides enable row level security;
alter table public.fare_offers enable row level security;
alter table public.ride_events enable row level security;
alter table public.ratings enable row level security;

create policy "Riders and their driver read the ride; admins all" on public.rides for select to authenticated
  using (passenger_id = (select auth.uid()) or driver_id = (select auth.uid()) or public.is_admin());
create policy "Passengers request rides" on public.rides for insert to authenticated
  with check (passenger_id = (select auth.uid()) and status = 'requested'
    and driver_id is null and vehicle_id is null and agreed_fare_kobo is null
    and final_fare_kobo is null and cancelled_by is null
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.status = 'active'));
create policy "Admins update rides" on public.rides for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "Offer parties read offers" on public.fare_offers for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin()
    or exists (select 1 from public.rides r where r.id = ride_id and r.passenger_id = (select auth.uid())));
create policy "Approved online drivers make offers" on public.fare_offers for insert to authenticated
  with check (driver_id = (select auth.uid()) and status = 'pending'
    and exists (select 1 from public.drivers d where d.id = (select auth.uid()) and d.status = 'approved' and d.is_online)
    and exists (select 1 from public.rides r where r.id = ride_id and r.status = 'requested'
      and r.pricing_mode = 'negotiable' and r.passenger_id <> (select auth.uid())));

create policy "Ride parties read events" on public.ride_events for select to authenticated
  using (public.is_admin() or exists (select 1 from public.rides r where r.id = ride_id
    and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid()))));

create policy "Users read ratings they gave or got" on public.ratings for select to authenticated
  using (rater_id = (select auth.uid()) or ratee_id = (select auth.uid()) or public.is_admin());
create policy "Ride parties rate each other after the trip" on public.ratings for insert to authenticated
  with check (rater_id = (select auth.uid()) and exists (
    select 1 from public.rides r where r.id = ride_id and r.status = 'completed'
      and ((r.passenger_id = (select auth.uid()) and r.driver_id = ratee_id)
        or (r.driver_id = (select auth.uid()) and r.passenger_id = ratee_id))));
