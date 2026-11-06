create index if not exists drainage_created_by_idx
  on public.drainage_inspection_records(created_by);
create index if not exists drainage_updated_by_idx
  on public.drainage_inspection_records(updated_by);
