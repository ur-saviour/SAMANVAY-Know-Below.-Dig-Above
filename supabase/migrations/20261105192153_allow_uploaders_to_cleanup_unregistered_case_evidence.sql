-- Permit an uploader to remove an object orphaned by a failed metadata insert.
-- The uploader must own the user-id folder and be authorised to see the referenced case.
drop policy if exists "SAMANVAY evidence delete by uploader" on storage.objects;
create policy "SAMANVAY evidence delete by uploader"
  on storage.objects for delete to authenticated
  using (
    bucket_id='samanvay-case-evidence'
    and (storage.foldername(name))[2]=(select auth.uid())::text
    and exists (
      select 1 from public.excavation_requests r
      where r.id::text=(storage.foldername(name))[1]
    )
  );
