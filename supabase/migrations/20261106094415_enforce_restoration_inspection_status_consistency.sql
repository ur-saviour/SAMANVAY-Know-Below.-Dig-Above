
alter table public.road_restoration_records
  drop constraint if exists road_restoration_rework_consistency;

alter table public.road_restoration_records
  add constraint road_restoration_inspection_status_consistency
  check (
    (inspection_outcome <> 'accepted' or restoration_status = 'accepted')
    and
    (inspection_outcome <> 'rework_required' or restoration_status = 'rework_required')
    and
    (restoration_status <> 'rework_required' or inspection_outcome = 'rework_required')
  );
