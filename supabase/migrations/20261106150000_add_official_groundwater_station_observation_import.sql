create table if not exists public.groundwater_station_observations (
  id uuid primary key default gen_random_uuid(),
  source_resource_id text not null,
  source_record_id bigint not null,
  station_name text not null,
  agency text not null,
  state_lgd_code text,
  state_name text not null,
  district_lgd_code text,
  district_name text not null,
  tehsil text,
  block_name text,
  village_name text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  rl_msl_m numeric(10,3),
  observed_at_local timestamp without time zone not null,
  reported_level_m numeric(10,3),
  reported_level_text text,
  source_dataset_url text not null,
  imported_at timestamptz not null default now(),
  constraint groundwater_station_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint groundwater_station_longitude_range check (longitude is null or longitude between -180 and 180),
  constraint groundwater_station_source_record_unique unique (source_resource_id, source_record_id)
);
create index if not exists groundwater_station_district_time_idx
  on public.groundwater_station_observations (district_name, observed_at_local desc);
create index if not exists groundwater_station_identity_time_idx
  on public.groundwater_station_observations
  (district_name, station_name, latitude, longitude, observed_at_local desc);
alter table public.groundwater_station_observations enable row level security;
drop policy if exists "Authenticated users can read official groundwater station observations"
  on public.groundwater_station_observations;
create policy "Authenticated users can read official groundwater station observations"
  on public.groundwater_station_observations for select to authenticated using (true);
revoke all on public.groundwater_station_observations from anon, authenticated;
grant select on public.groundwater_station_observations to authenticated;
create table if not exists public.groundwater_data_import_runs (
  id uuid primary key default gen_random_uuid(),
  source_resource_id text not null,
  district_scope text not null,
  status text not null check (status in ('running','completed','failed')),
  records_imported integer not null default 0 check (records_imported >= 0),
  source_records_total integer not null default 0 check (source_records_total >= 0),
  requested_by uuid not null references public.profiles(id),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  error_summary text
);
create index if not exists groundwater_data_import_runs_started_idx
  on public.groundwater_data_import_runs (started_at desc);
alter table public.groundwater_data_import_runs enable row level security;
revoke all on public.groundwater_data_import_runs from anon, authenticated;
create or replace view public.latest_groundwater_station_observations
with (security_invoker = true) as
select distinct on (district_name, station_name, latitude, longitude)
  id, source_resource_id, source_record_id, station_name, agency,
  state_lgd_code, state_name, district_lgd_code, district_name,
  tehsil, block_name, village_name, latitude, longitude, rl_msl_m,
  observed_at_local, reported_level_m, reported_level_text,
  source_dataset_url, imported_at
from public.groundwater_station_observations
order by district_name, station_name, latitude, longitude, observed_at_local desc;
grant select on public.latest_groundwater_station_observations to authenticated;
revoke all on public.latest_groundwater_station_observations from anon;
