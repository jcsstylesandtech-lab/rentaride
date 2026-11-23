-- Applied to Supabase project apebeihmocdomsrhefqs as "07_staff_access_and_offer_fix".
-- ===== Fix: drivers could not make offers (they cannot read unassigned rides) =====
create or replace function public.ride_open_for_offers(p_ride_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rides r where r.id = p_ride_id
    and r.status = 'requested' and r.pricing_mode = 'negotiable'
    and r.passenger_id <> (select auth.uid()));
$$;
alter policy "Approved online drivers make offers" on public.fare_offers
  with check (driver_id = (select auth.uid()) and status = 'pending'
    and exists (select 1 from public.drivers d where d.id = (select auth.uid()) and d.status = 'approved' and d.is_online)
    and public.ride_open_for_offers(ride_id));

-- ===== Employee access for the admin dashboard =====
create type public.staff_role as enum ('super_admin', 'operations', 'verifier', 'support', 'finance');

create table public.staff_members (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  staff_role public.staff_role not null,
  active boolean not null default true,
  added_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index staff_members_added_by_idx on public.staff_members (added_by);
create trigger staff_members_updated_at before update on public.staff_members
  for each row execute function public.set_updated_at();

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles (id),
  action text not null check (char_length(action) <= 80),
  target_table text,
  target_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index audit_log_created_idx on public.audit_log (created_at desc);
create index audit_log_actor_idx on public.audit_log (actor_id);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.staff_members s join public.profiles p on p.id = s.user_id
                 where s.user_id = (select auth.uid()) and s.active and p.status = 'active')
      or exists (select 1 from public.profiles
                 where id = (select auth.uid()) and role = 'admin' and status = 'active');
$$;

create or replace function public.has_staff_role(p_roles public.staff_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.staff_members s join public.profiles p on p.id = s.user_id
                 where s.user_id = (select auth.uid()) and s.active and p.status = 'active'
                   and (s.staff_role = 'super_admin' or s.staff_role = any (p_roles)));
$$;

create or replace function public.my_staff_role()
returns public.staff_role language sql stable security definer set search_path = '' as $$
  select s.staff_role from public.staff_members s join public.profiles p on p.id = s.user_id
  where s.user_id = (select auth.uid()) and s.active and p.status = 'active';
$$;

alter table public.staff_members enable row level security;
alter table public.audit_log enable row level security;

create policy "Staff read the staff list" on public.staff_members for select to authenticated
  using (public.is_admin());
create policy "Super admins manage staff" on public.staff_members for all to authenticated
  using (public.has_staff_role('{}')) with check (public.has_staff_role('{}') and user_id <> (select auth.uid()));
create policy "Staff read the audit log" on public.audit_log for select to authenticated
  using (public.has_staff_role('{operations}'));
create policy "Staff write their own audit entries" on public.audit_log for insert to authenticated
  with check (actor_id = (select auth.uid()) and public.is_admin());

-- Narrow staff write access to the right roles (rules changed in place).
alter policy "Users update their own profile; admins update any" on public.profiles
  using (id = (select auth.uid()) or public.has_staff_role('{operations}'))
  with check (id = (select auth.uid()) or public.has_staff_role('{operations}'));
alter policy "Drivers update own row; admins all" on public.drivers
  using (id = (select auth.uid()) or public.has_staff_role('{verifier,operations}'))
  with check (id = (select auth.uid()) or public.has_staff_role('{verifier,operations}'));
alter policy "Drivers manage own vehicles; admins all" on public.vehicles
  using (driver_id = (select auth.uid()) or public.has_staff_role('{verifier,operations}'))
  with check (driver_id = (select auth.uid()) or public.has_staff_role('{verifier,operations}'));
alter policy "Admins review documents" on public.driver_documents
  using (public.has_staff_role('{verifier}')) with check (public.has_staff_role('{verifier}'));
alter policy "Admins update rides" on public.rides
  using (public.has_staff_role('{operations}')) with check (public.has_staff_role('{operations}'));
alter policy "Admins handle SOS" on public.sos_alerts
  using (public.has_staff_role('{support,operations}')) with check (public.has_staff_role('{support,operations}'));
alter policy "Users read own payments" on public.payments
  using (user_id = (select auth.uid()) or public.has_staff_role('{finance}'));
alter policy "Users read own wallet" on public.wallets
  using (user_id = (select auth.uid()) or public.has_staff_role('{finance}'));
alter policy "Users read own wallet history" on public.wallet_transactions
  using (user_id = (select auth.uid()) or public.has_staff_role('{finance}'));

create or replace function public.guard_profile_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not public.has_staff_role('{operations}') then
    new.role := old.role;
    new.status := old.status;
    new.rating_avg := old.rating_avg;
    new.rating_count := old.rating_count;
    new.phone_verified := old.phone_verified;
    new.phone := old.phone;
  end if;
  if new.role = 'admin' and old.role <> 'admin' and (select auth.uid()) is not null then
    new.role := old.role;
  end if;
  return new;
end $$;

alter publication supabase_realtime add table public.sos_alerts, public.drivers, public.driver_documents;

revoke execute on function public.ride_open_for_offers, public.has_staff_role, public.my_staff_role
  from public, anon;
grant execute on function public.ride_open_for_offers, public.has_staff_role, public.my_staff_role
  to authenticated;
