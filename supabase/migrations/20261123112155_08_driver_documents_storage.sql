-- Applied to Supabase project apebeihmocdomsrhefqs as "08_driver_documents_storage".
-- Private bucket: files at driver-documents/<driver uuid>/<file>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('driver-documents', 'driver-documents', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do nothing;

create policy "Drivers upload into their own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Drivers read their own files; verifiers read all" on storage.objects for select to authenticated
  using (bucket_id = 'driver-documents'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.has_staff_role('{verifier,operations}')));
