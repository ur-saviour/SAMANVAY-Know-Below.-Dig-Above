create index if not exists road_restoration_department_idx
  on public.road_restoration_records(responsible_department_id);
create index if not exists road_restoration_created_by_idx
  on public.road_restoration_records(created_by);
create index if not exists road_restoration_updated_by_idx
  on public.road_restoration_records(updated_by);