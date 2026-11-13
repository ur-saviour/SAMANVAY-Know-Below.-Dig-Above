-- SAMANVAY Beta 0.2: controlled requests for official account access.
-- New accounts remain Citizens until an administrator approves an access request.

create table if not exists public.account_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_role text not null
    check (requested_role in ('department', 'coordinator', 'admin')),
  department_id uuid references public.departments(id) on delete restrict,
  reason text not null check (char_length(trim(reason)) between 10 and 1000),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  review_notes text,
  constraint account_access_department_required
    check ((requested_role = 'department' and department_id is not null)
        or (requested_role <> 'department' and department_id is null)),
  constraint account_access_review_state
    check ((status = 'pending' and reviewed_at is null and reviewed_by is null)
        or (status <> 'pending' and reviewed_at is not null and reviewed_by is not null))
);

create unique index if not exists account_access_one_pending_per_user
  on public.account_access_requests(user_id)
  where status = 'pending';

create index if not exists account_access_requests_status_requested_at_idx
  on public.account_access_requests(status, requested_at desc);

alter table public.account_access_requests enable row level security;

drop policy if exists "Users read own access requests" on public.account_access_requests;
create policy "Users read own access requests"
  on public.account_access_requests for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Admins read all access requests" on public.account_access_requests;
create policy "Admins read all access requests"
  on public.account_access_requests for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  ));

drop policy if exists "Users submit own pending access requests" on public.account_access_requests;
create policy "Users submit own pending access requests"
  on public.account_access_requests for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'requester'
    )
  );

create or replace function public.admin_review_access_request(
  p_request_id uuid,
  p_decision text,
  p_review_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_request public.account_access_requests%rowtype;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  ) then
    raise exception 'Administrator access required';
  end if;

  if p_decision not in ('approve', 'reject') then
    raise exception 'Decision must be approve or reject';
  end if;

  select * into v_request
  from public.account_access_requests
  where id = p_request_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending access request not found';
  end if;

  if v_request.user_id = (select auth.uid()) then
    raise exception 'Administrators cannot review their own access request';
  end if;

  if p_decision = 'approve' then
    perform public.admin_update_profile_role(
      v_request.user_id,
      v_request.requested_role,
      v_request.department_id
    );
  end if;

  update public.account_access_requests
  set status = case when p_decision = 'approve' then 'approved' else 'rejected' end,
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      review_notes = nullif(trim(p_review_notes), '')
  where id = p_request_id;

  insert into public.admin_audit_events(
    actor_id, target_user_id, event_type, details
  ) values (
    (select auth.uid()),
    v_request.user_id,
    'account_access_request_' || p_decision,
    jsonb_build_object(
      'request_id', p_request_id,
      'requested_role', v_request.requested_role,
      'department_id', v_request.department_id,
      'review_notes', p_review_notes
    )
  );

  insert into public.user_notifications(
    recipient_id, notification_type, title, body, data
  ) values (
    v_request.user_id,
    'system',
    'SAMANVAY official access request reviewed',
    case when p_decision = 'approve'
      then 'Your requested platform access has been approved.'
      else 'Your requested platform access was not approved. Contact an administrator for details.'
    end,
    jsonb_build_object('request_id', p_request_id, 'decision', p_decision)
  );
end;
$function$;

revoke all on function public.admin_review_access_request(uuid, text, text) from public, anon;
grant execute on function public.admin_review_access_request(uuid, text, text) to authenticated;

grant select, insert on public.account_access_requests to authenticated;

-- Administrator-only view of pending official access applications.
create or replace function public.admin_access_request_directory()
returns table(
  request_id uuid,
  user_id uuid,
  display_name text,
  requested_role text,
  department_id uuid,
  department_name text,
  reason text,
  requested_at timestamptz
)
language plpgsql
security definer
set search_path=''
as $function$
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role='admin'
  ) then
    raise exception 'Administrator access required';
  end if;
  return query
  select r.id,r.user_id,p.display_name,r.requested_role,r.department_id,d.name,r.reason,r.requested_at
  from public.account_access_requests r
  join public.profiles p on p.id=r.user_id
  left join public.departments d on d.id=r.department_id
  where r.status='pending'
  order by r.requested_at asc;
end;
$function$;
revoke all on function public.admin_access_request_directory() from public,anon;
grant execute on function public.admin_access_request_directory() to authenticated;
