-- Restrict case-collaboration rows to the requester, assigned department staff,
-- and authorised coordination / administrator roles.
drop policy if exists "Case participants can read coordination checks"
  on public.case_coordination_checks;

create policy "Case participants can read coordination checks"
  on public.case_coordination_checks
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.excavation_requests as r
      where r.id = case_coordination_checks.request_id
        and (
          r.requester_id = (select auth.uid())
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role in ('admin', 'coordinator')
          )
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role = 'department'
              and p.department_id = r.department_id
          )
          or public.is_department_assigned_to_request(r.id)
        )
    )
  );

drop policy if exists "Case participants can read messages"
  on public.case_messages;

create policy "Case participants can read messages"
  on public.case_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.excavation_requests as r
      where r.id = case_messages.request_id
        and (
          r.requester_id = (select auth.uid())
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role in ('admin', 'coordinator')
          )
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role = 'department'
              and p.department_id = r.department_id
          )
          or public.is_department_assigned_to_request(r.id)
        )
    )
  );

drop policy if exists "Case participants can send messages"
  on public.case_messages;

create policy "Case participants can send messages"
  on public.case_messages
  for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1
      from public.excavation_requests as r
      where r.id = case_messages.request_id
        and (
          r.requester_id = (select auth.uid())
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role in ('admin', 'coordinator')
          )
          or exists (
            select 1 from public.profiles as p
            where p.id = (select auth.uid())
              and p.role = 'department'
              and p.department_id = r.department_id
          )
          or public.is_department_assigned_to_request(r.id)
        )
    )
  );

-- Notify the citizen when an authorised officer changes the case status.
create or replace function public.samanvay_notify_case_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.user_notifications (
    recipient_id,
    request_id,
    notification_type,
    title,
    body,
    data
  )
  values (
    new.requester_id,
    new.id,
    'status',
    'Case status updated',
    'Your case "' || left(new.title, 120) || '" is now ' ||
      replace(new.status, '_', ' ') || '.',
    jsonb_build_object(
      'previous_status', old.status,
      'new_status', new.status
    )
  );

  return new;
end;
$function$;

revoke all on function public.samanvay_notify_case_status_change()
  from public, anon, authenticated;

drop trigger if exists samanvay_notify_case_status_change
  on public.excavation_requests;

create trigger samanvay_notify_case_status_change
  after update of status on public.excavation_requests
  for each row
  execute function public.samanvay_notify_case_status_change();
