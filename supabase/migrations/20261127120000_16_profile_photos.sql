-- Profile photos for passengers, drivers and staff.
--
-- Photos live in a public bucket so the other side of a trip can see them
-- (ride_participants already returns avatar_url). Each user writes only
-- inside their own folder: avatars/<user id>/<file>.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "Users upload their own photo"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Needed to delete the previous photo (the public URL serves reads).
create policy "Users see their own photo files"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Users delete their own photo"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- avatar_url may only point at the user's own file in the avatars bucket,
-- so nobody can set an arbitrary (or someone else's) image.
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not public.has_staff_role('{operations}') then
    new.role := old.role;
    new.status := old.status;
    new.rating_avg := old.rating_avg;
    new.rating_count := old.rating_count;
    new.phone_verified := old.phone_verified;
    new.phone := old.phone;
    if new.avatar_url is distinct from old.avatar_url
       and new.avatar_url is not null
       and new.avatar_url not like '%/storage/v1/object/public/avatars/' || new.id::text || '/%' then
      raise exception 'Profile photo must be uploaded through the app'
        using errcode = '22023';
    end if;
  end if;
  if new.role = 'admin' and old.role <> 'admin' and (select auth.uid()) is not null then
    new.role := old.role;
  end if;
  return new;
end $$;
