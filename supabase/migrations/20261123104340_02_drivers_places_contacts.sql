-- Applied to Supabase project apebeihmocdomsrhefqs as "02_drivers_places_contacts".
create type public.driver_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type public.vehicle_class as enum ('economy', 'comfort', 'premium', 'suv', 'motorcycle');
create type public.document_type as enum ('drivers_licence', 'national_id', 'vehicle_registration', 'insurance', 'roadworthiness', 'vehicle_photo', 'profile_photo');
create type public.review_status as enum ('pending', 'approved', 'rejected');

-- Driver details (one per driver profile). Approved by admins.
create table public.drivers (
  id uuid primary key references public.profiles (id) on delete cascade,
  status public.driver_status not null default 'pending',
  licence_number text check (char_length(licence_number) <= 40),
  is_online boolean not null default false,
  rejection_reason text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger drivers_updated_at before update on public.drivers
  for each row execute function public.set_updated_at();

-- Drivers may only toggle online (when approved) and edit their licence
-- number while pending; status changes are for admins / the backend.
create or replace function public.guard_driver_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not public.is_admin() then
    new.status := old.status;
    new.rejection_reason := old.rejection_reason;
    new.approved_at := old.approved_at;
    if old.status <> 'approved' then new.is_online := false; end if;
    if old.status = 'approved' then new.licence_number := old.licence_number; end if;
  end if;
  return new;
end $$;
create trigger drivers_guard before update on public.drivers
  for each row execute function public.guard_driver_update();

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  class public.vehicle_class not null default 'economy',
  make text not null check (char_length(make) <= 40),
  model text not null check (char_length(model) <= 40),
  colour text not null check (char_length(colour) <= 30),
  year smallint check (year between 1990 and 2100),
  plate_number text not null unique check (char_length(plate_number) <= 15),
  seats smallint not null default 4 check (seats between 1 and 8),
  is_active boolean not null default true,
  review public.review_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicles_driver_idx on public.vehicles (driver_id);
create trigger vehicles_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();

create or replace function public.guard_vehicle_review()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not public.is_admin() then
    if tg_op = 'INSERT' then new.review := 'pending';
    else
      new.review := case
        when (new.make, new.model, new.colour, new.year, new.plate_number, new.class)
             is distinct from (old.make, old.model, old.colour, old.year, old.plate_number, old.class)
        then 'pending'::public.review_status else old.review end;
    end if;
  end if;
  return new;
end $$;
create trigger vehicles_guard before insert or update on public.vehicles
  for each row execute function public.guard_vehicle_review();

-- Uploaded files live in Supabase Storage; this table tracks review.
create table public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers (id) on delete cascade,
  type public.document_type not null,
  storage_path text not null,
  review public.review_status not null default 'pending',
  reviewer_note text,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  expires_on date,
  created_at timestamptz not null default now()
);
create index driver_documents_driver_idx on public.driver_documents (driver_id);

-- Latest GPS position of each driver (written by the driver app).
create table public.driver_locations (
  driver_id uuid primary key references public.drivers (id) on delete cascade,
  location extensions.geography (point, 4326) not null,
  heading_deg real check (heading_deg >= 0 and heading_deg < 360),
  speed_kmh real check (speed_kmh >= 0),
  updated_at timestamptz not null default now()
);
create index driver_locations_geo_idx on public.driver_locations using gist (location);

-- Home, Work and favourite places.
create table public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  slot text not null default 'favourite' check (slot in ('home', 'work', 'favourite')),
  name text not null check (char_length(name) <= 120),
  address text not null default '' check (char_length(address) <= 250),
  location extensions.geography (point, 4326) not null,
  created_at timestamptz not null default now()
);
create unique index saved_places_one_home_work on public.saved_places (user_id, slot)
  where slot in ('home', 'work');
create index saved_places_user_idx on public.saved_places (user_id);

create table public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  phone text not null check (phone ~ '^\+234[0-9]{10}$'),
  created_at timestamptz not null default now()
);
create index emergency_contacts_user_idx on public.emergency_contacts (user_id);

-- Row level security
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.driver_documents enable row level security;
alter table public.driver_locations enable row level security;
alter table public.saved_places enable row level security;
alter table public.emergency_contacts enable row level security;

create policy "Drivers read own row; admins all" on public.drivers for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());
create policy "Driver profiles register themselves" on public.drivers for insert to authenticated
  with check (id = (select auth.uid()) and status = 'pending'
    and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'driver'));
create policy "Drivers update own row; admins all" on public.drivers for update to authenticated
  using (id = (select auth.uid()) or public.is_admin())
  with check (id = (select auth.uid()) or public.is_admin());

create policy "Drivers manage own vehicles; admins all" on public.vehicles for all to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin())
  with check (driver_id = (select auth.uid()) or public.is_admin());

create policy "Drivers read own documents; admins all" on public.driver_documents for select to authenticated
  using (driver_id = (select auth.uid()) or public.is_admin());
create policy "Drivers upload own documents" on public.driver_documents for insert to authenticated
  with check (driver_id = (select auth.uid()) and review = 'pending'
    and reviewed_by is null and reviewed_at is null);
create policy "Admins review documents" on public.driver_documents for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Passengers never read this table directly; they use nearby_drivers().
create policy "Approved online drivers write own location" on public.driver_locations for all to authenticated
  using (driver_id = (select auth.uid()))
  with check (driver_id = (select auth.uid())
    and exists (select 1 from public.drivers d where d.id = (select auth.uid()) and d.status = 'approved'));
create policy "Admins read driver locations" on public.driver_locations for select to authenticated
  using (public.is_admin());

create policy "Users manage own saved places" on public.saved_places for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Users manage own emergency contacts" on public.emergency_contacts for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Admins read emergency contacts" on public.emergency_contacts for select to authenticated
  using (public.is_admin());
