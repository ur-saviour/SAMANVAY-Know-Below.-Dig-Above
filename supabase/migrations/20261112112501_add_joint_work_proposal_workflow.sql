-- SAMANVAY joint-work proposal workflow.
-- Additive: does not change case status, utility geometry, permit or clearance permissions.

create table if not exists public.case_joint_work_proposals (
  id uuid primary key default gen_random_uuid(),
  primary_request_id uuid not null references public.excavation_requests(id) on delete restrict,
  related_request_id uuid not null references public.excavation_requests(id) on delete restrict,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  proposal_status text not null default 'pending_department_responses'
    check (proposal_status in ('pending_department_responses','declined','ready_for_coordinator','scheduled','rejected_by_coordinator','withdrawn')),
  reason text not null check (char_length(btrim(reason)) between 10 and 2000),
  proposed_start_on date,
  proposed_end_on date,
  scheduled_start_on date,
  scheduled_end_on date,
  coordinator_remarks text,
  finalised_by uuid references public.profiles(id) on delete restrict,
  finalised_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint case_joint_work_distinct_requests check (primary_request_id <> related_request_id),
  constraint case_joint_work_proposed_dates check (proposed_start_on is null or proposed_end_on is null or proposed_end_on >= proposed_start_on),
  constraint case_joint_work_scheduled_dates check (
    (scheduled_start_on is null and scheduled_end_on is null)
    or (scheduled_start_on is not null and scheduled_end_on is not null and scheduled_end_on >= scheduled_start_on)
  ),
  constraint case_joint_work_finalisation_check check (
    proposal_status not in ('scheduled','rejected_by_coordinator')
    or (finalised_by is not null and finalised_at is not null)
  )
);

create index if not exists case_joint_work_proposals_creator_created_idx
  on public.case_joint_work_proposals(created_by, created_at desc);
create index if not exists case_joint_work_proposals_status_created_idx
  on public.case_joint_work_proposals(proposal_status, created_at desc);
create unique index if not exists case_joint_work_proposals_active_pair_uidx
  on public.case_joint_work_proposals (
    least(primary_request_id, related_request_id),
    greatest(primary_request_id, related_request_id)
  )
  where proposal_status not in ('declined','rejected_by_coordinator','withdrawn');

create table if not exists public.case_joint_work_responses (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.case_joint_work_proposals(id) on delete restrict,
  department_id uuid not null references public.departments(id) on delete restrict,
  response_status text not null default 'pending'
    check (response_status in ('pending','accepted','declined')),
  response_remarks text,
  responded_by uuid references public.profiles(id) on delete restrict,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (proposal_id, department_id),
  constraint case_joint_work_response_actor_check check (
    (response_status = 'pending' and responded_by is null and responded_at is null)
    or (response_status in ('accepted','declined') and responded_by is not null and responded_at is not null)
  )
);
create index if not exists case_joint_work_responses_department_status_idx
  on public.case_joint_work_responses(department_id, response_status, proposal_id);

create table if not exists public.case_joint_work_events (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.case_joint_work_proposals(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  event_type text not null check (event_type in (
    'proposal_created','department_accepted','department_declined',
    'proposal_ready','proposal_declined','proposal_scheduled','proposal_rejected'
  )),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists case_joint_work_events_timeline_idx
  on public.case_joint_work_events(proposal_id, created_at desc);

alter table public.case_joint_work_proposals enable row level security;
alter table public.case_joint_work_responses enable row level security;
alter table public.case_joint_work_events enable row level security;

-- Clients can read records visible to their role, but cannot write workflow state directly.
revoke all on public.case_joint_work_proposals from anon, authenticated;
revoke all on public.case_joint_work_responses from anon, authenticated;
revoke all on public.case_joint_work_events from anon, authenticated;
grant select on public.case_joint_work_proposals to authenticated;
grant select on public.case_joint_work_responses to authenticated;
grant select on public.case_joint_work_events to authenticated;

create or replace function public.samanvay_can_view_joint_work_proposal(p_proposal_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.case_joint_work_proposals p
      where p.id = p_proposal_id
        and (
          p.created_by = (select auth.uid())
          or exists (
            select 1 from public.profiles me
            where me.id = (select auth.uid())
              and me.role in ('admin','coordinator')
          )
          or exists (
            select 1
            from public.case_joint_work_responses r
            join public.profiles me on me.id = (select auth.uid())
            where r.proposal_id = p.id
              and me.role = 'department'
              and me.department_id is not null
              and r.department_id = me.department_id
          )
        )
    );
$function$;

revoke all on function public.samanvay_can_view_joint_work_proposal(uuid) from public, anon;
grant execute on function public.samanvay_can_view_joint_work_proposal(uuid) to authenticated;

drop policy if exists "Joint work proposal participants read proposals" on public.case_joint_work_proposals;
create policy "Joint work proposal participants read proposals"
  on public.case_joint_work_proposals for select to authenticated
  using ((select public.samanvay_can_view_joint_work_proposal(id)));

drop policy if exists "Joint work proposal participants read responses" on public.case_joint_work_responses;
create policy "Joint work proposal participants read responses"
  on public.case_joint_work_responses for select to authenticated
  using ((select public.samanvay_can_view_joint_work_proposal(proposal_id)));

drop policy if exists "Joint work proposal participants read events" on public.case_joint_work_events;
create policy "Joint work proposal participants read events"
  on public.case_joint_work_events for select to authenticated
  using ((select public.samanvay_can_view_joint_work_proposal(proposal_id)));

create or replace function public.create_case_joint_work_proposal(
  p_primary_request_id uuid,
  p_related_request_id uuid,
  p_reason text,
  p_proposed_start_on date default null,
  p_proposed_end_on date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_departments uuid[];
  v_department_count integer;
  v_proposal_id uuid;
  v_primary_status text;
  v_related_status text;
begin
  if v_uid is null then raise exception 'Authentication is required'; end if;
  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is null or v_role not in ('admin','coordinator') then
    raise exception 'Only administrators and coordinators can create joint-work proposals';
  end if;
  if p_primary_request_id is null or p_related_request_id is null
     or p_primary_request_id = p_related_request_id then
    raise exception 'Select two different infrastructure cases';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 10
     or char_length(btrim(p_reason)) > 2000 then
    raise exception 'Provide a reason between 10 and 2000 characters';
  end if;
  if p_proposed_start_on is not null and p_proposed_end_on is not null
     and p_proposed_end_on < p_proposed_start_on then
    raise exception 'Proposed end date cannot be before the proposed start date';
  end if;

  select r.status into v_primary_status
  from public.excavation_requests r where r.id = p_primary_request_id;
  if not found then raise exception 'The first case was not found'; end if;
  select r.status into v_related_status
  from public.excavation_requests r where r.id = p_related_request_id;
  if not found then raise exception 'The second case was not found'; end if;
  if v_primary_status in ('completed','rejected') or v_related_status in ('completed','rejected') then
    raise exception 'Completed or rejected cases cannot be proposed for joint work';
  end if;

  select coalesce(array_agg(x.department_id order by x.department_id), '{}'::uuid[])
  into v_departments
  from (
    select r.department_id
    from public.excavation_requests r
    where r.id in (p_primary_request_id,p_related_request_id)
      and r.department_id is not null
    union
    select dr.department_id
    from public.request_department_reviews dr
    where dr.request_id in (p_primary_request_id,p_related_request_id)
  ) x;
  v_department_count := coalesce(array_length(v_departments,1),0);
  if v_department_count < 2 then
    raise exception 'The selected cases must involve at least two distinct assigned departments';
  end if;

  if exists (
    select 1 from public.case_joint_work_proposals p
    where least(p.primary_request_id,p.related_request_id)
            = least(p_primary_request_id,p_related_request_id)
      and greatest(p.primary_request_id,p.related_request_id)
            = greatest(p_primary_request_id,p_related_request_id)
      and p.proposal_status not in ('declined','rejected_by_coordinator','withdrawn')
  ) then
    raise exception 'An active joint-work proposal already exists for these two cases';
  end if;

  insert into public.case_joint_work_proposals(
    primary_request_id,related_request_id,created_by,reason,
    proposed_start_on,proposed_end_on
  ) values (
    p_primary_request_id,p_related_request_id,v_uid,btrim(p_reason),
    p_proposed_start_on,p_proposed_end_on
  ) returning id into v_proposal_id;

  insert into public.case_joint_work_responses(proposal_id,department_id)
  select v_proposal_id, unnest(v_departments);

  insert into public.case_joint_work_events(proposal_id,actor_id,event_type,details)
  values(v_proposal_id,v_uid,'proposal_created',
    jsonb_build_object('department_count',v_department_count));

  insert into public.user_notifications(
    recipient_id,request_id,notification_type,title,body,data
  )
  select distinct prof.id,p_primary_request_id,'system',
    'Joint-work proposal requires your response',
    'Your department has been included in a proposal to coordinate two infrastructure cases. Review it in SAMANVAY.',
    jsonb_build_object('proposal_id',v_proposal_id,'related_request_id',p_related_request_id)
  from public.profiles prof
  where prof.role = 'department'
    and prof.department_id = any(v_departments);

  return jsonb_build_object(
    'proposal_id',v_proposal_id,
    'department_count',v_department_count,
    'proposal_status','pending_department_responses'
  );
end;
$function$;

create or replace function public.respond_case_joint_work_proposal(
  p_proposal_id uuid,
  p_response_status text,
  p_remarks text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_department_id uuid;
  v_creator_id uuid;
  v_request_id uuid;
  v_status text;
  v_next_status text;
  v_response_id uuid;
begin
  if v_uid is null then raise exception 'Authentication is required'; end if;
  if p_response_status is null or p_response_status not in ('accepted','declined') then
    raise exception 'Response must be accepted or declined';
  end if;
  if p_remarks is not null and char_length(p_remarks) > 1500 then
    raise exception 'Response remarks cannot exceed 1500 characters';
  end if;
  select p.role,p.department_id into v_role,v_department_id
  from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'department' or v_department_id is null then
    raise exception 'Only an assigned department officer can respond';
  end if;

  select p.created_by,p.primary_request_id,p.proposal_status
  into v_creator_id,v_request_id,v_status
  from public.case_joint_work_proposals p
  where p.id = p_proposal_id
  for update;
  if not found then raise exception 'Joint-work proposal not found'; end if;
  if v_status <> 'pending_department_responses' then
    raise exception 'This proposal is no longer accepting department responses';
  end if;

  update public.case_joint_work_responses r
  set response_status = p_response_status,
      response_remarks = nullif(btrim(coalesce(p_remarks,'')),''),
      responded_by = v_uid,
      responded_at = now()
  where r.proposal_id = p_proposal_id
    and r.department_id = v_department_id
    and r.response_status = 'pending'
  returning r.id into v_response_id;
  if v_response_id is null then
    raise exception 'Your department has no pending response for this proposal';
  end if;

  if p_response_status = 'declined' then
    v_next_status := 'declined';
    update public.case_joint_work_proposals
    set proposal_status = v_next_status, updated_at = now()
    where id = p_proposal_id;
    insert into public.case_joint_work_events(proposal_id,actor_id,event_type,details)
    values(p_proposal_id,v_uid,'department_declined',
      jsonb_build_object('department_id',v_department_id,'remarks',p_remarks));
  else
    if exists (
      select 1 from public.case_joint_work_responses r
      where r.proposal_id = p_proposal_id and r.response_status = 'pending'
    ) then
      v_next_status := 'pending_department_responses';
    else
      v_next_status := 'ready_for_coordinator';
    end if;
    update public.case_joint_work_proposals
    set proposal_status = v_next_status, updated_at = now()
    where id = p_proposal_id;
    insert into public.case_joint_work_events(proposal_id,actor_id,event_type,details)
    values(p_proposal_id,v_uid,
      case when v_next_status = 'ready_for_coordinator'
        then 'proposal_ready' else 'department_accepted' end,
      jsonb_build_object('department_id',v_department_id,'remarks',p_remarks));
  end if;

  insert into public.user_notifications(
    recipient_id,request_id,notification_type,title,body,data
  )
  select p.id,v_request_id,'system','Joint-work proposal response updated',
    'A participating department submitted its response. The proposal status is now ' ||
      replace(v_next_status,'_',' ') || '.',
    jsonb_build_object('proposal_id',p_proposal_id,'proposal_status',v_next_status)
  from public.profiles p
  where (p.id = v_creator_id or p.role in ('admin','coordinator'))
    and p.id <> v_uid;

  return jsonb_build_object(
    'proposal_id',p_proposal_id,
    'proposal_status',v_next_status,
    'response_status',p_response_status
  );
end;
$function$;

create or replace function public.finalise_case_joint_work_proposal(
  p_proposal_id uuid,
  p_decision text,
  p_scheduled_start_on date default null,
  p_scheduled_end_on date default null,
  p_remarks text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_creator_id uuid;
  v_request_id uuid;
  v_status text;
  v_new_status text;
  v_title text;
begin
  if v_uid is null then raise exception 'Authentication is required'; end if;
  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is null or v_role not in ('admin','coordinator') then
    raise exception 'Only administrators and coordinators can finalise a joint-work proposal';
  end if;
  if p_decision is null or p_decision not in ('schedule','reject') then
    raise exception 'Decision must be schedule or reject';
  end if;
  if p_remarks is not null and char_length(p_remarks) > 2000 then
    raise exception 'Coordinator remarks cannot exceed 2000 characters';
  end if;

  select p.created_by,p.primary_request_id,p.proposal_status
  into v_creator_id,v_request_id,v_status
  from public.case_joint_work_proposals p
  where p.id = p_proposal_id
  for update;
  if not found then raise exception 'Joint-work proposal not found'; end if;
  if v_status in ('scheduled','rejected_by_coordinator','withdrawn') then
    raise exception 'This proposal has already been finalised';
  end if;

  if p_decision = 'schedule' then
    if v_status <> 'ready_for_coordinator' then
      raise exception 'All participating departments must accept before scheduling';
    end if;
    if p_scheduled_start_on is null or p_scheduled_end_on is null
       or p_scheduled_end_on < p_scheduled_start_on then
      raise exception 'Provide a valid scheduled start and end date';
    end if;
    if exists (
      select 1 from public.case_joint_work_responses r
      where r.proposal_id = p_proposal_id and r.response_status <> 'accepted'
    ) then
      raise exception 'Every participating department must have an accepted response';
    end if;
    v_new_status := 'scheduled';
    v_title := 'Joint work scheduled';
    update public.case_joint_work_proposals
    set proposal_status = v_new_status,
        scheduled_start_on = p_scheduled_start_on,
        scheduled_end_on = p_scheduled_end_on,
        coordinator_remarks = nullif(btrim(coalesce(p_remarks,'')),''),
        finalised_by = v_uid, finalised_at = now(), updated_at = now()
    where id = p_proposal_id;
    insert into public.case_joint_work_events(proposal_id,actor_id,event_type,details)
    values(p_proposal_id,v_uid,'proposal_scheduled',
      jsonb_build_object('scheduled_start_on',p_scheduled_start_on,
        'scheduled_end_on',p_scheduled_end_on,'remarks',p_remarks));
  else
    v_new_status := 'rejected_by_coordinator';
    v_title := 'Joint-work proposal not approved';
    update public.case_joint_work_proposals
    set proposal_status = v_new_status,
        coordinator_remarks = nullif(btrim(coalesce(p_remarks,'')),''),
        finalised_by = v_uid, finalised_at = now(), updated_at = now()
    where id = p_proposal_id;
    insert into public.case_joint_work_events(proposal_id,actor_id,event_type,details)
    values(p_proposal_id,v_uid,'proposal_rejected',
      jsonb_build_object('remarks',p_remarks));
  end if;

  insert into public.user_notifications(
    recipient_id,request_id,notification_type,title,body,data
  )
  select distinct prof.id,v_request_id,'system',v_title,
    case when v_new_status = 'scheduled'
      then 'A coordinator recorded a shared planning schedule for this proposal.'
      else 'A coordinator reviewed and rejected the joint-work proposal.' end,
    jsonb_build_object('proposal_id',p_proposal_id,'proposal_status',v_new_status)
  from public.profiles prof
  where prof.id = v_creator_id
     or prof.id in (
       select participant.id
       from public.case_joint_work_responses r
       join public.profiles participant on participant.department_id = r.department_id
       where r.proposal_id = p_proposal_id and participant.role = 'department'
     )
     or prof.role in ('admin','coordinator');

  return jsonb_build_object(
    'proposal_id',p_proposal_id,
    'proposal_status',v_new_status,
    'decision',p_decision
  );
end;
$function$;

revoke all on function public.create_case_joint_work_proposal(uuid,uuid,text,date,date) from public, anon;
revoke all on function public.respond_case_joint_work_proposal(uuid,text,text) from public, anon;
revoke all on function public.finalise_case_joint_work_proposal(uuid,text,date,date,text) from public, anon;
grant execute on function public.create_case_joint_work_proposal(uuid,uuid,text,date,date) to authenticated;
grant execute on function public.respond_case_joint_work_proposal(uuid,text,text) to authenticated;
grant execute on function public.finalise_case_joint_work_proposal(uuid,text,date,date,text) to authenticated;
