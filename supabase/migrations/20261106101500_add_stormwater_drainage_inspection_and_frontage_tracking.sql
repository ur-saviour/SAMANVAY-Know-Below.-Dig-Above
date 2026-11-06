create table if not exists public.drainage_inspection_records (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  responsible_department_id uuid not null references public.departments(id) on delete restrict,
  obstruction_type text not null check (obstruction_type in (
    'blocked_inlet','silt_debris','encroachment','damaged_drain',
    'missing_frontage_drain','inadequate_capacity','other'
  )),
  severity text not null default 'moderate'
    check (severity in ('low','moderate','high','critical')),
  action_status text not null default 'reported'
    check (action_status in ('reported','inspection_required','action_assigned','in_progress','cleared','monitoring')),
  standing_water boolean not null default false,
  inlet_clear boolean not null default false,
  outfall_clear boolean not null default false,
  frontage_drain_present boolean not null default true,
  inspection_notes text check (inspection_notes is null or char_length(btrim(inspection_notes)) <= 6000),
  inspected_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id) on delete restrict,
  updated_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drainage_unique_request_department unique (request_id,responsible_department_id),
  constraint drainage_clearance_gate check (
    action_status <> 'cleared' or (inlet_clear and outfall_clear and not standing_water)
  )
);

create index if not exists drainage_action_status_inspected_idx
  on public.drainage_inspection_records(action_status, inspected_at desc);
create index if not exists drainage_request_updated_idx
  on public.drainage_inspection_records(request_id, updated_at desc);
create index if not exists drainage_department_idx
  on public.drainage_inspection_records(responsible_department_id);

alter table public.drainage_inspection_records enable row level security;

create policy "Participants can view drainage inspection records"
  on public.drainage_inspection_records for select to authenticated
  using (
    exists (select 1 from public.excavation_requests r
      where r.id = drainage_inspection_records.request_id and r.requester_id = (select auth.uid()))
    or exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator') or
        (p.role = 'department'
          and p.department_id = drainage_inspection_records.responsible_department_id
          and public.is_department_assigned_to_request(drainage_inspection_records.request_id))))
  );

create policy "Assigned staff can create drainage inspection records"
  on public.drainage_inspection_records for insert to authenticated
  with check (
    created_by = (select auth.uid()) and updated_by = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator') or
        (p.role = 'department'
          and p.department_id = drainage_inspection_records.responsible_department_id
          and public.is_department_assigned_to_request(drainage_inspection_records.request_id))))
  );

create policy "Assigned staff can update drainage inspection records"
  on public.drainage_inspection_records for update to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator') or
        (p.role = 'department'
          and p.department_id = drainage_inspection_records.responsible_department_id
          and public.is_department_assigned_to_request(drainage_inspection_records.request_id))))
  )
  with check (
    updated_by = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator') or
        (p.role = 'department'
          and p.department_id = drainage_inspection_records.responsible_department_id
          and public.is_department_assigned_to_request(drainage_inspection_records.request_id))))
  );

create or replace function public.set_drainage_inspection_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  new.inspected_at := now();
  return new;
end;
$$;

create trigger drainage_inspection_updated_at
  before update on public.drainage_inspection_records
  for each row execute function public.set_drainage_inspection_updated_at();

revoke all on public.drainage_inspection_records from anon, public;
grant select, insert on public.drainage_inspection_records to authenticated;
grant update (obstruction_type,severity,action_status,standing_water,inlet_clear,
  outfall_clear,frontage_drain_present,inspection_notes,updated_by)
  on public.drainage_inspection_records to authenticated;
revoke all on function public.set_drainage_inspection_updated_at() from public,anon,authenticated;

create or replace function public.save_drainage_inspection_record(
  p_request_id uuid,p_responsible_department_id uuid,p_obstruction_type text,
  p_severity text,p_action_status text,p_standing_water boolean,
  p_inlet_clear boolean,p_outfall_clear boolean,p_frontage_drain_present boolean,
  p_inspection_notes text
)
returns jsonb language plpgsql security invoker set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_previous_status text;
  v_record_id uuid;
  v_inspection_id uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  select d.action_status into v_previous_status
  from public.drainage_inspection_records d
  where d.request_id=p_request_id
    and d.responsible_department_id=p_responsible_department_id
  for update;

  insert into public.drainage_inspection_records (
    request_id,responsible_department_id,obstruction_type,severity,action_status,
    standing_water,inlet_clear,outfall_clear,frontage_drain_present,
    inspection_notes,created_by,updated_by
  ) values (
    p_request_id,p_responsible_department_id,p_obstruction_type,p_severity,p_action_status,
    coalesce(p_standing_water,false),coalesce(p_inlet_clear,false),
    coalesce(p_outfall_clear,false),coalesce(p_frontage_drain_present,true),
    p_inspection_notes,v_user_id,v_user_id
  )
  on conflict (request_id,responsible_department_id) do update set
    obstruction_type=excluded.obstruction_type,severity=excluded.severity,
    action_status=excluded.action_status,standing_water=excluded.standing_water,
    inlet_clear=excluded.inlet_clear,outfall_clear=excluded.outfall_clear,
    frontage_drain_present=excluded.frontage_drain_present,
    inspection_notes=excluded.inspection_notes,updated_by=v_user_id
  returning id into v_record_id;

  if p_action_status is distinct from v_previous_status
     and nullif(btrim(coalesce(p_inspection_notes,'')),'') is not null then
    insert into public.case_inspections (
      request_id,inspection_type,outcome,notes,inspected_by
    ) values (
      p_request_id,'progress',
      case when p_action_status='cleared' then 'pass' else 'follow_up_required' end,
      btrim(p_inspection_notes),v_user_id
    )
    returning id into v_inspection_id;
  end if;

  return jsonb_build_object('record_id',v_record_id,'inspection_id',v_inspection_id,
    'inspection_event_created',v_inspection_id is not null);
end;
$function$;

revoke all on function public.save_drainage_inspection_record(
  uuid,uuid,text,text,text,boolean,boolean,boolean,boolean,text
) from public,anon;
grant execute on function public.save_drainage_inspection_record(
  uuid,uuid,text,text,text,boolean,boolean,boolean,boolean,text
) to authenticated;
