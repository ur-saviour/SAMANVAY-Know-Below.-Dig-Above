-- Additive field-inspection capture metadata. Device-reported location is not
-- represented as survey verification or proof of positional accuracy.
alter table public.case_inspections
  add column if not exists location_latitude double precision,
  add column if not exists location_longitude double precision,
  add column if not exists location_accuracy_m double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists location_capture_method text not null default 'not_captured';

alter table public.case_attachments
  add column if not exists inspection_id uuid
    references public.case_inspections(id) on delete set null,
  add column if not exists captured_at timestamptz,
  add column if not exists captured_latitude double precision,
  add column if not exists captured_longitude double precision,
  add column if not exists location_accuracy_m double precision,
  add column if not exists sha256 text;

alter table public.case_inspections
  drop constraint if exists case_inspections_location_capture_check;
alter table public.case_inspections
  add constraint case_inspections_location_capture_check
  check (
    location_capture_method in ('not_captured','device_gps')
    and (
      (
        location_capture_method = 'not_captured'
        and location_latitude is null
        and location_longitude is null
        and location_accuracy_m is null
        and location_captured_at is null
      )
      or
      (
        location_capture_method = 'device_gps'
        and location_latitude between -90 and 90
        and location_longitude between -180 and 180
        and location_accuracy_m >= 0
        and location_accuracy_m <= 10000
        and location_captured_at is not null
      )
    )
  );

alter table public.case_attachments
  drop constraint if exists case_attachments_capture_metadata_check;
alter table public.case_attachments
  add constraint case_attachments_capture_metadata_check
  check (
    (
      captured_latitude is null
      and captured_longitude is null
      and location_accuracy_m is null
    )
    or
    (
      captured_latitude between -90 and 90
      and captured_longitude between -180 and 180
      and location_accuracy_m >= 0
      and location_accuracy_m <= 10000
    )
  );

alter table public.case_attachments
  drop constraint if exists case_attachments_sha256_check;
alter table public.case_attachments
  add constraint case_attachments_sha256_check
  check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$');

create index if not exists case_attachments_inspection_id_idx
  on public.case_attachments(inspection_id)
  where inspection_id is not null;
create index if not exists case_inspections_request_inspected_idx
  on public.case_inspections(request_id, inspected_at desc);

comment on column public.case_inspections.location_latitude is
  'Device-reported inspection latitude (WGS84); not independently surveyed or verified.';
comment on column public.case_inspections.location_longitude is
  'Device-reported inspection longitude (WGS84); not independently surveyed or verified.';
comment on column public.case_inspections.location_accuracy_m is
  'Device-reported horizontal accuracy in metres at capture time.';
comment on column public.case_inspections.location_captured_at is
  'Timestamp reported by the device location provider.';
comment on column public.case_attachments.inspection_id is
  'Optional link to the staff inspection that produced this attachment.';
comment on column public.case_attachments.sha256 is
  'SHA-256 of uploaded attachment bytes; proves byte identity only, not authenticity.';

drop policy if exists "Case participants can add their own attachment records"
  on public.case_attachments;
create policy "Case participants can add their own attachment records"
  on public.case_attachments for insert to authenticated
  with check (
    uploaded_by = (select auth.uid())
    and storage_path like (
      request_id::text || '/' || (select auth.uid())::text || '/%'
    )
    and exists (
      select 1 from public.excavation_requests r
      where r.id = case_attachments.request_id
    )
    and (
      inspection_id is null
      or exists (
        select 1
        from public.case_inspections i
        join public.profiles p on p.id = (select auth.uid())
        where i.id = case_attachments.inspection_id
          and i.request_id = case_attachments.request_id
          and i.inspected_by = (select auth.uid())
          and (
            p.role in ('admin','coordinator')
            or (
              p.role = 'department'
              and public.is_department_assigned_to_request(i.request_id)
            )
          )
      )
    )
  );

notify pgrst, 'reload schema';
