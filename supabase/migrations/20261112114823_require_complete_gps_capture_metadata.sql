
alter table public.case_inspections
  drop constraint if exists case_inspections_location_capture_check;
alter table public.case_inspections
  add constraint case_inspections_location_capture_check
  check (
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
      and location_latitude is not null
      and location_longitude is not null
      and location_accuracy_m is not null
      and location_captured_at is not null
      and location_latitude between -90 and 90
      and location_longitude between -180 and 180
      and location_accuracy_m >= 0
      and location_accuracy_m <= 10000
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
      captured_latitude is not null
      and captured_longitude is not null
      and location_accuracy_m is not null
      and captured_latitude between -90 and 90
      and captured_longitude between -180 and 180
      and location_accuracy_m >= 0
      and location_accuracy_m <= 10000
    )
  );
