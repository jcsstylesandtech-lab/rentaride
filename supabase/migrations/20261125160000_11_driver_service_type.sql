-- Applied to Supabase project apebeihmocdomsrhefqs as "11_driver_service_type".
-- What a driver does on the platform: carry passengers, dispatch (bike
-- courier) or delivery (van / car parcels and goods).
create type public.service_type as enum ('ride', 'dispatch', 'delivery');

alter table public.drivers
  add column service_type public.service_type not null default 'ride';
create index drivers_service_status_idx on public.drivers (service_type, status);

-- Drivers choose their service while applying; once approved only staff can change it.
create or replace function public.guard_driver_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not public.is_admin() then
    new.status := old.status;
    new.rejection_reason := old.rejection_reason;
    new.approved_at := old.approved_at;
    if old.status <> 'approved' then new.is_online := false; end if;
    if old.status = 'approved' then
      new.licence_number := old.licence_number;
      new.service_type := old.service_type;
    end if;
  end if;
  return new;
end $$;
