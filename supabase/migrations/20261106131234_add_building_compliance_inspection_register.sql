create table if not exists public.building_compliance_inspections (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete restrict,
  responsible_department_id uuid not null references public.departments(id) on delete restrict,
  approval_reference text,
  issuing_authority text,
  approved_floor_count integer,
  observed_floor_count integer not null,
  approved_height_m numeric(8,2),
  observed_height_m numeric(8,2),
  review_state text not null default 'awaiting_review'
    check (review_state in ('awaiting_review','reviewed_consistent','refer_to_authority')),
  inspection_notes text,
  inspected_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint building_compliance_floor_counts_nonnegative
    check ((approved_floor_count is null or approved_floor_count >= 0) and observed_floor_count >= 0),
  constraint building_compliance_heights_nonnegative
    check ((approved_height_m is null or approved_height_m >= 0) and (observed_height_m is null or observed_height_m >= 0)),
  constraint building_compliance_approval_metadata
    check (approved_floor_count is not null or approved_height_m is not null or nullif(btrim(coalesce(approval_reference,'')), '') is not null)
);

create index if not exists building_compliance_request_inspected_idx
  on public.building_compliance_inspections (request_id, inspected_at desc);
create index if not exists building_compliance_department_inspected_idx
  on public.building_compliance_inspections (responsible_department_id, inspected_at desc);

alter table public.building_compliance_inspections enable row level security;

drop policy if exists "Participants can view building compliance inspections"
  on public.building_compliance_inspections;
create policy "Participants can view building compliance inspections"
  on public.building_compliance_inspections
  for select to authenticated
  using (
    exists (
      select 1 from public.excavation_requests r
      where r.id = building_compliance_inspections.request_id
        and r.requester_id = (select auth.uid())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = building_compliance_inspections.responsible_department_id
            and public.is_department_assigned_to_request(building_compliance_inspections.request_id)
          )
        )
    )
  );

drop policy if exists "Assigned staff can create building compliance inspections"
  on public.building_compliance_inspections;
create policy "Assigned staff can create building compliance inspections"
  on public.building_compliance_inspections
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (
          p.role in ('admin','coordinator')
          or (
            p.role = 'department'
            and p.department_id = building_compliance_inspections.responsible_department_id
            and public.is_department_assigned_to_request(building_compliance_inspections.request_id)
          )
        )
    )
  );

revoke all on public.building_compliance_inspections from anon;
grant select, insert on public.building_compliance_inspections to authenticated;
