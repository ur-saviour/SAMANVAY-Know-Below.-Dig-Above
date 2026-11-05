-- Limit AI assessment mutation to coordinator/admin review decisions.
revoke update on public.case_ai_assessments from authenticated;
grant update (review_status, reviewed_by, reviewed_at)
  on public.case_ai_assessments to authenticated;

drop policy if exists "Coordinators review AI suggestions"
  on public.case_ai_assessments;
create policy "Coordinators review AI suggestions"
  on public.case_ai_assessments for update to authenticated
  using (
    review_status = 'suggested'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('admin','coordinator')
    )
  )
  with check (
    review_status in ('accepted','dismissed')
    and reviewed_by = (select auth.uid())
    and reviewed_at is not null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('admin','coordinator')
    )
  );

drop policy if exists "SAMANVAY evidence delete by uploader"
  on storage.objects;
create policy "SAMANVAY evidence delete by uploader"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'samanvay-case-evidence'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and exists (
      select 1 from public.case_attachments a
      where a.storage_path = storage.objects.name
        and a.uploaded_by = (select auth.uid())
    )
  );
