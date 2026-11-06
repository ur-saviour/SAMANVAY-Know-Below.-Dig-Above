create table if not exists public.groundwater_observation_records (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete restrict,
  responsible_department_id uuid not null references public.departments(id) on delete restrict,
  site_reference text not null,
  well_type text not null check (well_type in ('borewell','open_well','observation_well','other')),
  observation_method text not null check (observation_method in ('manual_measurement','sensor_reading','authority_record','field_inspection')),
  water_level_below_ground_m numeric(8,3) not null check (water_level_below_ground_m >= 0),
  pumping_state text not null default 'unknown' check (pumping_state in ('not_pumping','pumping','recovery','unknown')),
  source_type text not null default 'field_observed' check (source_type in ('field_observed','authority_document','sensor_snapshot')),
  source_reference text,
  measurement_notes text,
  observed_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists groundwater_observation_request_time_idx
  on public.groundwater_observation_records (request_id, observed_at desc);
create index if not exists groundwater_observation_department_time_idx
  on public.groundwater_observation_records (responsible_department_id, observed_at desc);
create index if not exists groundwater_observation_created_by_idx
  on public.groundwater_observation_records (created_by);
alter table public.groundwater_observation_records enable row level security;
create policy "Participants can view groundwater observations"
  on public.groundwater_observation_records for select to authenticated
  using (
    exists (select 1 from public.excavation_requests r
      where r.id = groundwater_observation_records.request_id
        and r.case_category = 'borewell_groundwater'
        and r.requester_id = (select auth.uid()))
    or exists (select 1 from public.profiles p
      where p.id = (select auth.uid()) and (
        p.role in ('admin','coordinator')
        or (p.role = 'department'
          and p.department_id = groundwater_observation_records.responsible_department_id
          and public.is_department_assigned_to_request(groundwater_observation_records.request_id))))
  );
create policy "Assigned staff can create groundwater observations"
  on public.groundwater_observation_records for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (select 1 from public.excavation_requests r
      where r.id = groundwater_observation_records.request_id
        and r.case_category = 'borewell_groundwater')
    and exists (select 1 from public.profiles p
      where p.id = (select auth.uid()) and (
        p.role in ('admin','coordinator')
        or (p.role = 'department'
          and p.department_id = groundwater_observation_records.responsible_department_id
          and public.is_department_assigned_to_request(groundwater_observation_records.request_id))))
  );
revoke all on public.groundwater_observation_records from anon, authenticated;
grant select, insert on public.groundwater_observation_records to authenticated;
