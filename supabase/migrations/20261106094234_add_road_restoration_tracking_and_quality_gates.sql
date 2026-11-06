create table if not exists public.road_restoration_records (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  responsible_department_id uuid not null references public.departments(id) on delete restrict,
  road_surface_type text not null
    check (road_surface_type in ('bituminous','concrete','interlocking_pavers','gravel','earthen','other')),
  restoration_status text not null default 'planned'
    check (restoration_status in ('planned','in_progress','awaiting_inspection','accepted','rework_required')),
  cut_length_m numeric(9,2) check (cut_length_m is null or cut_length_m between 0.10 and 10000),
  cut_width_m numeric(7,2) check (cut_width_m is null or cut_width_m between 0.10 and 100),
  restored_length_m numeric(9,2) check (restored_length_m is null or restored_length_m between 0.10 and 10000),
  restored_width_m numeric(7,2) check (restored_width_m is null or restored_width_m between 0.10 and 100),
  restoration_method text check (restoration_method is null or char_length(btrim(restoration_method)) between 1 and 500),
  planned_restore_date date,
  completed_at timestamptz,
  inspection_outcome text not null default 'not_inspected'
    check (inspection_outcome in ('not_inspected','accepted','rework_required')),
  compaction_verified boolean not null default false,
  drainage_clear boolean not null default false,
  surface_quality_notes text
    check (surface_quality_notes is null or char_length(btrim(surface_quality_notes)) <= 6000),
  created_by uuid not null references public.profiles(id) on delete restrict,
  updated_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint road_restoration_unique_request_department
    unique (request_id, responsible_department_id),
  constraint road_restoration_acceptance_quality_gate
    check (
      restoration_status <> 'accepted'
      or (
        inspection_outcome = 'accepted'
        and compaction_verified
        and drainage_clear
        and completed_at is not null
      )
    ),
  constraint road_restoration_rework_consistency
    check (
      restoration_status <> 'rework_required'
      or inspection_outcome = 'rework_required'
    )
);

create index if not exists road_restoration_status_due_idx
  on public.road_restoration_records(restoration_status, planned_restore_date);
create index if not exists road_restoration_request_updated_idx
  on public.road_restoration_records(request_id, updated_at desc);

alter table public.road_restoration_records enable row level security;

drop policy if exists "Participants can view road restoration records"
  on public.road_restoration_records;
create policy "Participants can view road restoration records"
  on public.road_restoration_records
  for select to authenticated
  using (
    exists (
      select 1 from public.excavation_requests r
      where r.id = road_restoration_records.request_id
        and r.requester_id = (select auth.uid())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = road_restoration_records.responsible_department_id
            and public.is_department_assigned_to_request(road_restoration_records.request_id)
          )
        )
    )
  );

drop policy if exists "Assigned staff can create road restoration records"
  on public.road_restoration_records;
create policy "Assigned staff can create road restoration records"
  on public.road_restoration_records
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and updated_by = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = road_restoration_records.responsible_department_id
            and public.is_department_assigned_to_request(road_restoration_records.request_id)
          )
        )
    )
  );

drop policy if exists "Assigned staff can update road restoration records"
  on public.road_restoration_records;
create policy "Assigned staff can update road restoration records"
  on public.road_restoration_records
  for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = road_restoration_records.responsible_department_id
            and public.is_department_assigned_to_request(road_restoration_records.request_id)
          )
        )
    )
  )
  with check (
    updated_by = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = road_restoration_records.responsible_department_id
            and public.is_department_assigned_to_request(road_restoration_records.request_id)
          )
        )
    )
  );

create or replace function public.set_road_restoration_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists road_restoration_updated_at
  on public.road_restoration_records;
create trigger road_restoration_updated_at
  before update on public.road_restoration_records
  for each row execute function public.set_road_restoration_updated_at();

revoke all on public.road_restoration_records from anon, public;
grant select, insert on public.road_restoration_records to authenticated;
grant update (
  road_surface_type, restoration_status, cut_length_m, cut_width_m,
  restored_length_m, restored_width_m, restoration_method,
  planned_restore_date, completed_at, inspection_outcome,
  compaction_verified, drainage_clear, surface_quality_notes, updated_by
) on public.road_restoration_records to authenticated;

revoke all on function public.set_road_restoration_updated_at() from public, anon, authenticated;
