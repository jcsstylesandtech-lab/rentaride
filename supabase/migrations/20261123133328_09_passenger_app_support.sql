-- Applied to Supabase project apebeihmocdomsrhefqs as "09_passenger_app_support".
-- Save the phone number typed at sign-up (unverified until SMS codes are
-- enabled). Skipped if another account already uses it.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  requested text := new.raw_user_meta_data ->> 'role';
  meta_phone text := new.raw_user_meta_data ->> 'phone';
  auth_phone text := case when new.phone is not null and new.phone <> '' then '+' || ltrim(new.phone, '+') end;
  chosen_phone text := coalesce(auth_phone,
    case when meta_phone ~ '^\+234[0-9]{10}$'
          and not exists (select 1 from public.profiles where phone = meta_phone)
         then meta_phone end);
begin
  insert into public.profiles (id, role, full_name, phone, email, phone_verified)
  values (
    new.id,
    case when requested = 'driver' then 'driver'::public.user_role else 'passenger'::public.user_role end,
    coalesce(left(new.raw_user_meta_data ->> 'full_name', 120), ''),
    chosen_phone,
    nullif(new.email, ''),
    new.phone_confirmed_at is not null
  );
  return new;
end $$;

-- Driver offers on the caller's negotiable ride, with what a passenger
-- needs to choose: first name, rating and car — never the phone number.
create or replace function public.offers_for_ride(p_ride_id uuid)
returns table (offer_id uuid, amount_kobo bigint, eta_minutes smallint, created_at timestamptz,
  driver_first_name text, driver_rating numeric, driver_rating_count integer,
  vehicle_make text, vehicle_model text, vehicle_colour text, vehicle_class public.vehicle_class)
language sql stable security definer set search_path = '' as $$
  select o.id, o.amount_kobo, o.eta_minutes, o.created_at,
         split_part(p.full_name, ' ', 1), p.rating_avg, p.rating_count,
         v.make, v.model, v.colour, v.class
  from public.fare_offers o
  join public.rides r on r.id = o.ride_id
  join public.profiles p on p.id = o.driver_id
  left join lateral (select make, model, colour, class from public.vehicles
                     where driver_id = o.driver_id and is_active and review = 'approved'
                       and class = r.vehicle_class limit 1) v on true
  where o.ride_id = p_ride_id and o.status = 'pending'
    and r.passenger_id = (select auth.uid())
  order by o.amount_kobo, o.created_at;
$$;

revoke execute on function public.offers_for_ride from public, anon;
grant execute on function public.offers_for_ride to authenticated;
revoke execute on function public.handle_new_user from public, anon, authenticated;
