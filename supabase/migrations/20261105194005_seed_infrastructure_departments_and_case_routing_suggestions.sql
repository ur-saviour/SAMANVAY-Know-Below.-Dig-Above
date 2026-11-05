-- Register municipal infrastructure routing groups and case-to-department suggestions.
insert into public.departments(name,description)
values
  ('Roads & Highways','Road reconstruction, resurfacing, trench coordination and road restoration. Confirm the competent road-owning authority for this jurisdiction.'),
  ('Groundwater & Borewell Regulation','Borewell registration, groundwater extraction oversight and local monitoring. Confirm the competent groundwater authority for this jurisdiction.'),
  ('Town Planning & Building Regulation','Building plan compliance, permitted floors, setbacks, land use and development control.'),
  ('Public Health Engineering','Public water supply, sanitation and public-health engineering coordination.'),
  ('Stormwater Management','Stormwater drains, flood pathways, surface drainage and drainage capacity.')
on conflict (name) do nothing;

alter table public.excavation_requests
  drop constraint if exists excavation_requests_case_category_check;
update public.excavation_requests
set case_category='legacy_excavation'
where case_category='road_reconstruction';
alter table public.excavation_requests
  alter column case_category set default 'legacy_excavation';
alter table public.excavation_requests
  add constraint excavation_requests_case_category_check
  check (case_category = any (array[
    'legacy_excavation','road_reconstruction','water_supply','sewerage',
    'stormwater_drainage','electricity','telecom','gas',
    'borewell_groundwater','building_planning','public_health_engineering','other'
  ]));

create table if not exists public.department_service_domains (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments(id) on delete cascade,
  case_category text not null check (case_category = any (array[
    'road_reconstruction','water_supply','sewerage','stormwater_drainage',
    'electricity','telecom','gas','borewell_groundwater',
    'building_planning','public_health_engineering','other'
  ])),
  route_priority text not null check (route_priority in ('primary','supporting')),
  created_at timestamptz not null default now(),
  unique(department_id,case_category)
);
create index if not exists department_service_domains_category_idx
  on public.department_service_domains(case_category,route_priority);
alter table public.department_service_domains enable row level security;
drop policy if exists "Authenticated users can view service routing map"
  on public.department_service_domains;
create policy "Authenticated users can view service routing map"
  on public.department_service_domains for select to authenticated
  using (true);
grant select on public.department_service_domains to authenticated;

-- These are advisory routing suggestions, not automatic assignments or statutory determinations.
insert into public.department_service_domains(department_id,case_category,route_priority)
select d.id,m.case_category,m.route_priority
from (values
  ('Roads & Highways','road_reconstruction','primary'),
  ('Municipal Corporation','road_reconstruction','supporting'),
  ('Water Supply','road_reconstruction','supporting'),
  ('Sewage and Drainage','road_reconstruction','supporting'),
  ('Stormwater Management','road_reconstruction','supporting'),
  ('Electricity','road_reconstruction','supporting'),
  ('Telecommunications','road_reconstruction','supporting'),
  ('Gas','road_reconstruction','supporting'),
  ('Water Supply','water_supply','primary'),
  ('Public Health Engineering','water_supply','supporting'),
  ('Municipal Corporation','water_supply','supporting'),
  ('Sewage and Drainage','sewerage','primary'),
  ('Public Health Engineering','sewerage','supporting'),
  ('Municipal Corporation','sewerage','supporting'),
  ('Stormwater Management','stormwater_drainage','primary'),
  ('Sewage and Drainage','stormwater_drainage','supporting'),
  ('Municipal Corporation','stormwater_drainage','supporting'),
  ('Electricity','electricity','primary'),
  ('Municipal Corporation','electricity','supporting'),
  ('Telecommunications','telecom','primary'),
  ('Municipal Corporation','telecom','supporting'),
  ('Gas','gas','primary'),
  ('Roads & Highways','gas','supporting'),
  ('Groundwater & Borewell Regulation','borewell_groundwater','primary'),
  ('Public Health Engineering','borewell_groundwater','supporting'),
  ('Municipal Corporation','borewell_groundwater','supporting'),
  ('Town Planning & Building Regulation','building_planning','primary'),
  ('Municipal Corporation','building_planning','supporting'),
  ('Public Health Engineering','public_health_engineering','primary'),
  ('Water Supply','public_health_engineering','supporting'),
  ('Sewage and Drainage','public_health_engineering','supporting'),
  ('Municipal Corporation','other','primary')
) as m(department_name,case_category,route_priority)
join public.departments d on d.name=m.department_name
on conflict(department_id,case_category) do update
set route_priority=excluded.route_priority;

alter table public.admin_audit_events
  drop constraint if exists admin_audit_events_event_type_check;
alter table public.admin_audit_events
  add constraint admin_audit_events_event_type_check
  check (event_type in ('profile_role_changed','department_created','service_domain_route_changed'));

create or replace function public.get_case_department_suggestions(p_case_category text)
returns table(department_id uuid,department_name text,description text,route_priority text)
language sql stable security invoker set search_path=''
as $function$
  select d.id,d.name,d.description,s.route_priority
  from public.department_service_domains s
  join public.departments d on d.id=s.department_id
  where s.case_category=p_case_category
  order by case s.route_priority when 'primary' then 0 else 1 end,d.name;
$function$;
revoke all on function public.get_case_department_suggestions(text) from public,anon;
grant execute on function public.get_case_department_suggestions(text) to authenticated;

create or replace function public.admin_set_service_domain_route(
  p_department_id uuid,p_case_category text,p_route_priority text,p_enabled boolean
)
returns void language plpgsql security definer set search_path=''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'
  ) then raise exception 'Administrator access required'; end if;
  if p_case_category not in (
    'road_reconstruction','water_supply','sewerage','stormwater_drainage',
    'electricity','telecom','gas','borewell_groundwater',
    'building_planning','public_health_engineering','other'
  ) then raise exception 'Unsupported case category'; end if;
  if p_route_priority not in ('primary','supporting') then raise exception 'Route priority must be primary or supporting'; end if;
  if not exists(select 1 from public.departments d where d.id=p_department_id) then raise exception 'Department not found'; end if;

  if p_enabled then
    insert into public.department_service_domains(department_id,case_category,route_priority)
    values(p_department_id,p_case_category,p_route_priority)
    on conflict(department_id,case_category) do update set route_priority=excluded.route_priority;
  else
    delete from public.department_service_domains
    where department_id=p_department_id and case_category=p_case_category;
  end if;

  insert into public.admin_audit_events(actor_id,event_type,details)
  values((select auth.uid()),'service_domain_route_changed',
    jsonb_build_object(
      'department_id',p_department_id,'case_category',p_case_category,
      'route_priority',p_route_priority,'enabled',p_enabled
    ));
end;
$function$;
revoke all on function public.admin_set_service_domain_route(uuid,text,text,boolean) from public,anon;
grant execute on function public.admin_set_service_domain_route(uuid,text,text,boolean) to authenticated;
