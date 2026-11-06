create table if not exists public.road_cut_permit_records (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  responsible_department_id uuid not null references public.departments(id),
  permit_status text not null default 'pending'
    check (permit_status in ('not_required','pending','issued','suspended','expired','revoked','closed')),
  permit_reference text,
  issuing_authority text,
  permit_valid_from date,
  permit_valid_until date,
  restoration_due_date date,
  work_started_at timestamptz,
  work_completed_at timestamptz,
  traffic_management_confirmed boolean not null default false,
  utility_clearance_confirmed boolean not null default false,
  road_safety_plan_confirmed boolean not null default false,
  notes text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint road_cut_permit_unique_case_department unique (request_id, responsible_department_id),
  constraint road_cut_permit_dates_valid check (
    (permit_valid_from is null or permit_valid_until is null or permit_valid_until >= permit_valid_from)
    and (restoration_due_date is null or permit_valid_from is null or restoration_due_date >= permit_valid_from)
    and (work_completed_at is null or work_started_at is null or work_completed_at >= work_started_at)
  ),
  constraint road_cut_permit_issued_fields check (
    permit_status not in ('issued','suspended','expired','revoked','closed')
    or (
      nullif(btrim(permit_reference), '') is not null
      and nullif(btrim(issuing_authority), '') is not null
      and permit_valid_from is not null
      and permit_valid_until is not null
    )
  ),
  constraint road_cut_permit_not_required_reason check (
    permit_status <> 'not_required' or nullif(btrim(notes), '') is not null
  )
);

create index if not exists road_cut_permit_deadline_idx
  on public.road_cut_permit_records (restoration_due_date, permit_status);
create index if not exists road_cut_permit_case_idx
  on public.road_cut_permit_records (request_id, responsible_department_id);

create or replace function public.validate_road_cut_permit_record()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();

  if new.permit_status = 'closed' then
    if new.work_completed_at is null then
      raise exception 'A closed permit must have a recorded work completion timestamp';
    end if;

    if not exists (
      select 1
      from public.road_restoration_records rr
      where rr.request_id = new.request_id
        and rr.responsible_department_id = new.responsible_department_id
        and rr.restoration_status = 'accepted'
        and rr.inspection_outcome = 'accepted'
        and rr.compaction_verified is true
        and rr.drainage_clear is true
        and rr.completed_at is not null
    ) then
      raise exception 'Permit close-out requires an accepted road-restoration inspection with compaction and drainage checks';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_road_cut_permit_record on public.road_cut_permit_records;
create trigger validate_road_cut_permit_record
before insert or update on public.road_cut_permit_records
for each row execute function public.validate_road_cut_permit_record();

alter table public.road_cut_permit_records enable row level security;

drop policy if exists "Participants can view road cut permit records" on public.road_cut_permit_records;
create policy "Participants can view road cut permit records"
on public.road_cut_permit_records
for select
to authenticated
using (
  exists (
    select 1
    from public.excavation_requests r
    where r.id = road_cut_permit_records.request_id
      and r.requester_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and (
        p.role in ('admin','coordinator')
        or (
          p.role = 'department'
          and p.department_id = road_cut_permit_records.responsible_department_id
          and public.is_department_assigned_to_request(road_cut_permit_records.request_id)
        )
      )
  )
);

drop policy if exists "Assigned staff can create road cut permit records" on public.road_cut_permit_records;
create policy "Assigned staff can create road cut permit records"
on public.road_cut_permit_records
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and (
        p.role in ('admin','coordinator')
        or (
          p.role = 'department'
          and p.department_id = road_cut_permit_records.responsible_department_id
          and public.is_department_assigned_to_request(road_cut_permit_records.request_id)
        )
      )
  )
);

drop policy if exists "Assigned staff can update road cut permit records" on public.road_cut_permit_records;
create policy "Assigned staff can update road cut permit records"
on public.road_cut_permit_records
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and (
        p.role in ('admin','coordinator')
        or (
          p.role = 'department'
          and p.department_id = road_cut_permit_records.responsible_department_id
          and public.is_department_assigned_to_request(road_cut_permit_records.request_id)
        )
      )
  )
)
with check (
  updated_by = (select auth.uid())
  and exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and (
        p.role in ('admin','coordinator')
        or (
          p.role = 'department'
          and p.department_id = road_cut_permit_records.responsible_department_id
          and public.is_department_assigned_to_request(road_cut_permit_records.request_id)
        )
      )
  )
);

revoke all on public.road_cut_permit_records from anon, public;
grant select, insert, update on public.road_cut_permit_records to authenticated;

create or replace view public.road_cut_permit_compliance
with (security_invoker = true)
as
select
  p.id,
  p.request_id,
  p.responsible_department_id,
  p.permit_status,
  p.permit_reference,
  p.issuing_authority,
  p.permit_valid_from,
  p.permit_valid_until,
  p.restoration_due_date,
  p.work_started_at,
  p.work_completed_at,
  p.traffic_management_confirmed,
  p.utility_clearance_confirmed,
  p.road_safety_plan_confirmed,
  p.notes,
  p.updated_at,
  case
    when p.permit_status = 'closed' then 'closed'
    when p.permit_status = 'not_required' then 'not_required'
    when p.permit_status = 'pending' then 'awaiting_permit'
    when p.permit_status = 'suspended' then 'suspended'
    when p.permit_status = 'revoked' then 'revoked'
    when p.permit_status = 'expired' or (p.permit_valid_until is not null and p.permit_valid_until < current_date) then 'permit_expired'
    when p.work_started_at is not null and (
      p.permit_valid_from is null or p.permit_valid_until is null
      or (p.work_started_at::date < p.permit_valid_from)
      or (p.work_started_at::date > p.permit_valid_until)
    ) then 'work_outside_permit_window'
    when p.work_completed_at is null and p.restoration_due_date is not null
      and p.restoration_due_date < current_date then 'restoration_overdue'
    when p.restoration_due_date is not null
      and p.restoration_due_date between current_date and current_date + 7 then 'restoration_due_soon'
    when p.permit_status = 'issued' then 'permit_active'
    else 'review_required'
  end as compliance_state,
  case when p.restoration_due_date is null then null
       else p.restoration_due_date - current_date end as days_to_restoration_due,
  case when p.permit_valid_until is null then null
       else p.permit_valid_until - current_date end as days_to_permit_expiry
from public.road_cut_permit_records p;

revoke all on public.road_cut_permit_compliance from anon, public;
grant select on public.road_cut_permit_compliance to authenticated;
