-- Administrator-only user directory, role assignment, department creation and audit.
create table if not exists public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id) on delete restrict,
  target_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('profile_role_changed','department_created')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists admin_audit_events_created_idx on public.admin_audit_events(created_at desc);
alter table public.admin_audit_events enable row level security;
drop policy if exists "Only administrators can read admin audit events" on public.admin_audit_events;
create policy "Only administrators can read admin audit events"
  on public.admin_audit_events for select to authenticated
  using (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));
grant select on public.admin_audit_events to authenticated;

create or replace function public.admin_user_directory()
returns table(user_id uuid,display_name text,role text,department_id uuid,department_name text,created_at timestamptz)
language plpgsql security definer set search_path=''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'
  ) then raise exception 'Administrator access required'; end if;
  return query
  select p.id,p.display_name,p.role,p.department_id,d.name,p.created_at
  from public.profiles p left join public.departments d on d.id=p.department_id
  order by p.created_at desc;
end;
$function$;
revoke all on function public.admin_user_directory() from public,anon;
grant execute on function public.admin_user_directory() to authenticated;

create or replace function public.admin_update_profile_role(
  p_user_id uuid,p_role text,p_department_id uuid default null
)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_old_role text; v_old_department uuid; v_new_department uuid;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'
  ) then raise exception 'Administrator access required'; end if;
  if p_user_id=(select auth.uid()) then raise exception 'Administrators cannot change their own role'; end if;
  if p_role not in ('requester','department','coordinator','admin') then raise exception 'Unsupported account role'; end if;

  if p_role='department' then
    if p_department_id is null or not exists (select 1 from public.departments d where d.id=p_department_id) then
      raise exception 'A valid department is required for department accounts';
    end if;
    v_new_department := p_department_id;
  else
    v_new_department := null;
  end if;

  select p.role,p.department_id into v_old_role,v_old_department
  from public.profiles p where p.id=p_user_id;
  if not found then raise exception 'User profile not found'; end if;
  if v_old_role='admin' and p_role<>'admin' and
    (select count(*) from public.profiles p where p.role='admin')<=1 then
    raise exception 'The last administrator cannot be demoted';
  end if;

  update public.profiles set role=p_role,department_id=v_new_department where id=p_user_id;
  insert into public.admin_audit_events(actor_id,target_user_id,event_type,details)
  values((select auth.uid()),p_user_id,'profile_role_changed',
    jsonb_build_object('old_role',v_old_role,'new_role',p_role,
      'old_department_id',v_old_department,'new_department_id',v_new_department));
  insert into public.user_notifications(recipient_id,notification_type,title,body,data)
  values(p_user_id,'system','SAMANVAY account access updated',
    'An administrator updated your platform role or department assignment.',
    jsonb_build_object('new_role',p_role,'department_id',v_new_department));
end;
$function$;
revoke all on function public.admin_update_profile_role(uuid,text,uuid) from public,anon;
grant execute on function public.admin_update_profile_role(uuid,text,uuid) to authenticated;

create or replace function public.admin_create_department(p_name text,p_description text default null)
returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_id uuid;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'
  ) then raise exception 'Administrator access required'; end if;
  if p_name is null or length(btrim(p_name))<2 or length(btrim(p_name))>120 then
    raise exception 'Department name must contain 2 to 120 characters';
  end if;
  if exists (select 1 from public.departments d where lower(d.name)=lower(btrim(p_name))) then
    raise exception 'A department with this name already exists';
  end if;
  insert into public.departments(name,description)
    values(btrim(p_name),nullif(btrim(coalesce(p_description,'')),''))
    returning id into v_id;
  insert into public.admin_audit_events(actor_id,event_type,details)
    values((select auth.uid()),'department_created',
      jsonb_build_object('department_id',v_id,'department_name',btrim(p_name)));
  return v_id;
end;
$function$;
revoke all on function public.admin_create_department(text,text) from public,anon;
grant execute on function public.admin_create_department(text,text) to authenticated;
