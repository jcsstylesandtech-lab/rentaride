-- Driver verification: home address and proof of address.

alter type public.document_type add value if not exists 'proof_of_address';

alter table public.drivers
  add column if not exists home_address text check (char_length(home_address) <= 250);

-- Drivers edit their address while applying; once approved only staff can change it.
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
      new.home_address := old.home_address;
    end if;
  end if;
  return new;
end $$;
