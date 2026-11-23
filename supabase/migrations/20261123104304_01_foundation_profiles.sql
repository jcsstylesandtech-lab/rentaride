-- Applied to Supabase project apebeihmocdomsrhefqs as "01_foundation_profiles".
-- Rent A Ride: foundation — extensions, enums, profiles, helpers.
create extension if not exists postgis with schema extensions;

create type public.user_role as enum ('passenger', 'driver', 'admin');
create type public.account_status as enum ('active', 'suspended', 'deleted');

-- Keeps updated_at current on every update.
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- One row per auth user (passengers, drivers and admins).
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'passenger',
  status public.account_status not null default 'active',
  full_name text not null default '' check (char_length(full_name) <= 120),
  phone text unique check (phone is null or phone ~ '^\+234[0-9]{10}$'),
  email text unique check (email is null or char_length(email) <= 254),
  avatar_url text,
  phone_verified boolean not null default false,
  share_trips_automatically boolean not null default false,
  rating_avg numeric(3, 2) not null default 5.00 check (rating_avg between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.profiles is 'Rent A Ride users. Phone numbers stay private: only the owner and admins can read a row.';

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- True when the signed-in user is an active admin.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin' and status = 'active'
  );
$$;

-- Users may edit their own details but never their role, status, rating
-- or verification flags. The backend (service role, no auth.uid()) and
-- admins may change anything.
create or replace function public.guard_profile_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not public.is_admin() then
    new.role := old.role;
    new.status := old.status;
    new.rating_avg := old.rating_avg;
    new.rating_count := old.rating_count;
    new.phone_verified := old.phone_verified;
    new.phone := old.phone;
  end if;
  return new;
end $$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_update();

-- Create the profile when someone signs up. Only 'passenger' or 'driver'
-- may be requested at sign-up; admins are promoted by another admin.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  requested text := new.raw_user_meta_data ->> 'role';
begin
  insert into public.profiles (id, role, full_name, phone, email, phone_verified)
  values (
    new.id,
    case when requested = 'driver' then 'driver'::public.user_role
         else 'passenger'::public.user_role end,
    coalesce(left(new.raw_user_meta_data ->> 'full_name', 120), ''),
    case when new.phone is not null and new.phone <> ''
         then '+' || ltrim(new.phone, '+') end,
    nullif(new.email, ''),
    new.phone_confirmed_at is not null
  );
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy "Users read their own profile; admins read all"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());

create policy "Users update their own profile; admins update any"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()) or public.is_admin())
  with check (id = (select auth.uid()) or public.is_admin());
