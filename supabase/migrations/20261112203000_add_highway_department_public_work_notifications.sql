-- Highway Department public works publishing and in-app notification fan-out.
-- Reuses the existing Roads & Highways department UUID so foreign keys and
-- prior assignments remain intact. Drafts stay private; notification fan-out
-- happens atomically only on the first sourced publication.

update public.departments
set name = 'Highway Department',
    description = coalesce(
      nullif(btrim(description), ''),
      'Plans, coordinates and publishes highway and major road works.'
    )
where lower(btrim(name)) = 'roads & highways';

insert into public.departments (name, description)
select 'Highway Department',
       'Plans, coordinates and publishes highway and major road works.'
where not exists (
  select 1 from public.departments where lower(btrim(name)) = 'highway department'
);

alter table public.user_notifications
  drop constraint if exists user_notifications_notification_type_check;

alter table public.user_notifications
  add constraint user_notifications_notification_type_check
  check (notification_type = any (array[
    'assignment'::text, 'review'::text, 'status'::text,
    'message'::text, 'system'::text, 'public_work'::text
  ]));

create or replace function public.publish_highway_work_notice(
  p_notice_id uuid,
  p_notice_status text,
  p_source_reference text,
  p_progress_percent smallint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_department_id uuid;
  v_department_name text;
  v_notice public.public_excavation_notices%rowtype;
  v_citizen_count integer := 0;
  v_municipal_count integer := 0;
  v_body text;
begin
  if v_actor is null then
    raise exception 'Authentication is required to publish a Highway Department notice.'
      using errcode = '28000';
  end if;

  select p.role, p.department_id, d.name
    into v_role, v_department_id, v_department_name
  from public.profiles p
  left join public.departments d on d.id = p.department_id
  where p.id = v_actor;

  if v_role is null then
    raise exception 'A registered SAMANVAY profile is required.'
      using errcode = '42501';
  end if;

  if p_notice_status not in ('published', 'active', 'completed', 'cancelled') then
    raise exception 'Choose a valid publication status.'
      using errcode = '22023';
  end if;

  if p_source_reference is null or char_length(btrim(p_source_reference)) < 3 then
    raise exception 'An official source reference is required before publication.'
      using errcode = '22023';
  end if;

  select * into v_notice
  from public.public_excavation_notices
  where id = p_notice_id
  for update;

  if not found then
    raise exception 'The requested public works notice was not found.'
      using errcode = 'P0002';
  end if;

  if v_notice.responsible_department_id is null
     or not exists (
       select 1 from public.departments d
       where d.id = v_notice.responsible_department_id
         and lower(btrim(d.name)) = 'highway department'
     ) then
    raise exception 'This publishing route is reserved for Highway Department notices.'
      using errcode = '42501';
  end if;

  if not (
    (v_role = 'department' and v_department_id = v_notice.responsible_department_id)
    or v_role in ('admin', 'coordinator')
  ) then
    raise exception 'Only the assigned Highway Department officer, a coordinator, or an administrator can publish this notice.'
      using errcode = '42501';
  end if;

  if v_notice.published_at is not null then
    return jsonb_build_object(
      'notice_id', v_notice.id,
      'already_published', true,
      'citizen_notifications', 0,
      'municipal_notifications', 0
    );
  end if;

  if v_notice.notice_status <> 'draft' then
    raise exception 'Only an unpublished draft can be published through this action.'
      using errcode = '55000';
  end if;

  update public.public_excavation_notices
  set notice_status = p_notice_status,
      source_reference = btrim(p_source_reference),
      progress_percent = p_progress_percent,
      published_at = now(),
      published_by = v_actor,
      updated_at = now()
  where id = p_notice_id
  returning * into v_notice;

  v_body := left(
    format(
      '%s in %s is scheduled from %s. Open Public works in SAMANVAY for the published notice and source reference.',
      v_notice.title,
      v_notice.city,
      to_char(v_notice.starts_on, 'DD Mon YYYY')
    ),
    500
  );

  insert into public.user_notifications (
    recipient_id, notification_type, title, body, data
  )
  select
    p.id,
    'public_work',
    left('Highway work notice: ' || v_notice.title, 140),
    v_body,
    jsonb_build_object(
      'kind', 'highway_public_work',
      'audience', 'citizen',
      'notice_id', v_notice.id,
      'notice_code', v_notice.notice_code,
      'city', v_notice.city,
      'area_label', v_notice.area_label,
      'department', 'Highway Department',
      'starts_on', v_notice.starts_on
    )
  from public.profiles p
  where p.role = 'requester';

  get diagnostics v_citizen_count = row_count;

  insert into public.user_notifications (
    recipient_id, notification_type, title, body, data
  )
  select
    p.id,
    'public_work',
    left('Highway work coordination: ' || v_notice.title, 140),
    v_body,
    jsonb_build_object(
      'kind', 'highway_public_work',
      'audience', 'municipal_department',
      'recipient_department', d.name,
      'notice_id', v_notice.id,
      'notice_code', v_notice.notice_code,
      'city', v_notice.city,
      'area_label', v_notice.area_label,
      'department', 'Highway Department',
      'starts_on', v_notice.starts_on
    )
  from public.profiles p
  join public.departments d on d.id = p.department_id
  where p.role = 'department'
    and lower(btrim(d.name)) in (
      'municipal corporation',
      'water supply',
      'sewage and drainage',
      'stormwater management',
      'public health engineering',
      'town planning & building regulation'
    );

  get diagnostics v_municipal_count = row_count;

  insert into public.public_excavation_notice_events (
    notice_id, event_type, title, details, progress_percent, created_by
  ) values (
    v_notice.id,
    'published',
    'Highway Department notice published',
    format(
      'Published with source reference %s. In-app notifications sent to %s Citizen account(s) and %s municipal service department officer account(s).',
      btrim(p_source_reference),
      v_citizen_count,
      v_municipal_count
    ),
    p_progress_percent,
    v_actor
  );

  return jsonb_build_object(
    'notice_id', v_notice.id,
    'already_published', false,
    'published_at', v_notice.published_at,
    'citizen_notifications', v_citizen_count,
    'municipal_notifications', v_municipal_count
  );
end;
$$;

revoke all on function public.publish_highway_work_notice(uuid, text, text, smallint)
  from public, anon, authenticated;
grant execute on function public.publish_highway_work_notice(uuid, text, text, smallint)
  to authenticated;

comment on function public.publish_highway_work_notice(uuid, text, text, smallint)
  is 'Atomically publishes a sourced Highway Department notice and notifies Citizen profiles and municipal service department officers.';
