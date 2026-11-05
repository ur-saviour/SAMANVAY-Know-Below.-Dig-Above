-- Expand SAMANVAY from excavation-only to multi-domain municipal infrastructure cases.
alter table public.excavation_requests
  add column if not exists case_category text not null default 'road_reconstruction',
  add column if not exists work_activity text not null default 'new_installation',
  add column if not exists work_radius_m numeric;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.excavation_requests'::regclass
      and conname='excavation_requests_case_category_check'
  ) then
    alter table public.excavation_requests
      add constraint excavation_requests_case_category_check
      check (case_category = any (array[
        'road_reconstruction','water_supply','sewerage','stormwater_drainage',
        'electricity','telecom','gas','borewell_groundwater',
        'building_planning','public_health_engineering','other'
      ]));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.excavation_requests'::regclass
      and conname='excavation_requests_work_activity_check'
  ) then
    alter table public.excavation_requests
      add constraint excavation_requests_work_activity_check
      check (work_activity = any (array[
        'new_installation','repair','maintenance','relocation',
        'survey','inspection','violation_report','emergency_response','other'
      ]));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.excavation_requests'::regclass
      and conname='excavation_requests_work_radius_check'
  ) then
    alter table public.excavation_requests
      add constraint excavation_requests_work_radius_check
      check (work_radius_m is null or (work_radius_m >= 1 and work_radius_m <= 500));
  end if;
end;
$$;

create index if not exists idx_requests_case_category
  on public.excavation_requests(case_category, created_at desc);

create table if not exists public.case_coordination_checks (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  checked_by uuid not null references public.profiles(id) on delete restrict,
  possible_overlap boolean not null,
  assessment_status text not null check (
    assessment_status in ('completed','missing_work_location','missing_work_radius','unavailable')
  ),
  advisory text not null,
  checked_at timestamptz not null default now()
);
create index if not exists case_coordination_checks_request_time_idx
  on public.case_coordination_checks(request_id, checked_at desc);
alter table public.case_coordination_checks enable row level security;
drop policy if exists "Case participants can read coordination checks"
  on public.case_coordination_checks;
create policy "Case participants can read coordination checks"
  on public.case_coordination_checks for select to authenticated
  using (exists (
    select 1 from public.excavation_requests r
    where r.id=case_coordination_checks.request_id
  ));
grant select on public.case_coordination_checks to authenticated;

create or replace function public.run_request_coordination_check(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
  v_requester_id uuid;
  v_work_location extensions.geometry;
  v_radius numeric;
  v_role text;
  v_possible_overlap boolean := false;
  v_status text := 'completed';
  v_advisory text;
  v_check_id uuid;
begin
  select r.requester_id,r.work_location,r.work_radius_m
    into v_requester_id,v_work_location,v_radius
  from public.excavation_requests r where r.id=p_request_id;
  if not found then raise exception 'Request not found'; end if;

  select p.role into v_role
  from public.profiles p where p.id=(select auth.uid());

  if v_role is null or not (
    v_role in ('admin','coordinator')
    or v_requester_id=(select auth.uid())
    or (v_role='department' and public.is_department_assigned_to_request(p_request_id))
  ) then
    raise exception 'You are not authorised to run this case coordination check';
  end if;

  if v_work_location is null then
    v_status := 'missing_work_location';
    v_advisory := 'Add an accurate work location before running the coordination check. A missing location is not proof that the site is clear.';
  elsif v_radius is null then
    v_status := 'missing_work_radius';
    v_advisory := 'Add the approximate work-site radius before running the coordination check. A missing radius is not proof that the site is clear.';
  else
    select exists (
      select 1 from gis.underground_assets a
      where extensions.st_dwithin(
        extensions.st_transform(a.geom,3857),
        extensions.st_transform(v_work_location,3857),
        (v_radius + coalesce(a.horizontal_accuracy_m,0) + 3)::double precision
      )
    ) into v_possible_overlap;

    if v_possible_overlap then
      v_advisory := 'Possible recorded infrastructure proximity detected. Obtain clearance directly from relevant utility-owning departments before any work.';
    else
      v_advisory := 'No overlap was detected in the records available to SAMANVAY. This is not proof of utility absence or site safety. Independent utility-owner confirmation and field verification remain mandatory.';
    end if;
  end if;

  insert into public.case_coordination_checks(
    request_id,checked_by,possible_overlap,assessment_status,advisory
  ) values (
    p_request_id,(select auth.uid()),v_possible_overlap,v_status,v_advisory
  ) returning id into v_check_id;

  return jsonb_build_object(
    'check_id',v_check_id,
    'assessment_status',v_status,
    'possible_overlap',v_possible_overlap,
    'advisory',v_advisory,
    'checked_at',now()
  );
end;
$function$;

revoke all on function public.run_request_coordination_check(uuid) from public,anon;
grant execute on function public.run_request_coordination_check(uuid) to authenticated;
