create index if not exists groundwater_data_import_runs_requested_by_idx
  on public.groundwater_data_import_runs (requested_by);
create unique index if not exists groundwater_data_import_one_active_run_uidx
  on public.groundwater_data_import_runs (status)
  where status = 'running';