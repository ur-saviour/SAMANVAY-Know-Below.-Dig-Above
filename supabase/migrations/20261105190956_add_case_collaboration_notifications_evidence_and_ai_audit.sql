-- SAMANVAY case collaboration, notifications, inspections, evidence and AI audit.
-- Additive migration. Preserves existing requests, profiles, department roles and GIS records.

create table if not exists public.case_messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists case_messages_request_created_idx
  on public.case_messages(request_id, created_at desc);
alter table public.case_messages enable row level security;
drop policy if exists "Case participants can read messages" on public.case_messages;
create policy "Case participants can read messages"
  on public.case_messages for select to authenticated
  using (exists (select 1 from public.excavation_requests r where r.id = case_messages.request_id));
drop policy if exists "Case participants can send messages" on public.case_messages;
create policy "Case participants can send messages"
  on public.case_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (select 1 from public.excavation_requests r where r.id = case_messages.request_id)
  );
grant select, insert on public.case_messages to authenticated;

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  request_id uuid references public.excavation_requests(id) on delete cascade,
  notification_type text not null check (notification_type in ('assignment','review','status','message','system')),
  title text not null check (char_length(title) between 1 and 140),
  body text not null check (char_length(body) between 1 and 500),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists user_notifications_recipient_created_idx
  on public.user_notifications(recipient_id, created_at desc);
create index if not exists user_notifications_unread_idx
  on public.user_notifications(recipient_id, created_at desc) where read_at is null;
alter table public.user_notifications enable row level security;
drop policy if exists "Users read their notifications" on public.user_notifications;
create policy "Users read their notifications"
  on public.user_notifications for select to authenticated
  using (recipient_id = (select auth.uid()));
drop policy if exists "Users mark their notifications read" on public.user_notifications;
create policy "Users mark their notifications read"
  on public.user_notifications for update to authenticated
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));
grant select on public.user_notifications to authenticated;
grant update (read_at) on public.user_notifications to authenticated;

create table if not exists public.case_inspections (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  inspection_type text not null check (inspection_type in ('pre_work','progress','post_work','utility_verification','safety_check','other')),
  outcome text not null check (outcome in ('pass','issue_found','follow_up_required','not_applicable')),
  notes text not null check (char_length(btrim(notes)) between 1 and 6000),
  inspected_at timestamptz not null default now(),
  inspected_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists case_inspections_request_time_idx
  on public.case_inspections(request_id, inspected_at desc);
alter table public.case_inspections enable row level security;
drop policy if exists "Case participants can read inspections" on public.case_inspections;
create policy "Case participants can read inspections"
  on public.case_inspections for select to authenticated
  using (exists (select 1 from public.excavation_requests r where r.id = case_inspections.request_id));
drop policy if exists "Assigned staff can record inspections" on public.case_inspections;
create policy "Assigned staff can record inspections"
  on public.case_inspections for insert to authenticated
  with check (
    inspected_by = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin','coordinator')
          or (p.role = 'department' and public.is_department_assigned_to_request(case_inspections.request_id)))
    )
    and exists (select 1 from public.excavation_requests r where r.id = case_inspections.request_id)
  );
grant select, insert on public.case_inspections to authenticated;

create table if not exists public.case_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null check (char_length(file_name) between 1 and 200),
  content_type text not null check (content_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  file_size_bytes bigint not null check (file_size_bytes between 1 and 20971520),
  attachment_type text not null check (attachment_type in ('site_photo','survey_evidence','permit','drawing','inspection_report','other')),
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint case_attachment_path_matches_owner check (
    storage_path like request_id::text || '/' || uploaded_by::text || '/%'
  )
);
create index if not exists case_attachments_request_created_idx
  on public.case_attachments(request_id, created_at desc);
alter table public.case_attachments enable row level security;
drop policy if exists "Case participants can read attachment records" on public.case_attachments;
create policy "Case participants can read attachment records"
  on public.case_attachments for select to authenticated
  using (exists (select 1 from public.excavation_requests r where r.id = case_attachments.request_id));
drop policy if exists "Case participants can add their own attachment records" on public.case_attachments;
create policy "Case participants can add their own attachment records"
  on public.case_attachments for insert to authenticated
  with check (
    uploaded_by = (select auth.uid())
    and storage_path like request_id::text || '/' || (select auth.uid())::text || '/%'
    and exists (select 1 from public.excavation_requests r where r.id = case_attachments.request_id)
  );
grant select, insert on public.case_attachments to authenticated;

create table if not exists public.case_ai_assessments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.excavation_requests(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  provider text not null default 'openai',
  model text not null,
  purpose text not null check (purpose in ('triage','summary','coordination')),
  assessment jsonb not null,
  review_status text not null default 'suggested' check (review_status in ('suggested','accepted','dismissed')),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists case_ai_assessments_request_created_idx
  on public.case_ai_assessments(request_id, created_at desc);
create index if not exists case_ai_assessments_user_created_idx
  on public.case_ai_assessments(created_by, created_at desc);
alter table public.case_ai_assessments enable row level security;
drop policy if exists "Authorised staff read AI assessments" on public.case_ai_assessments;
create policy "Authorised staff read AI assessments"
  on public.case_ai_assessments for select to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator')
        or (p.role = 'department' and public.is_department_assigned_to_request(case_ai_assessments.request_id))))
    and exists (select 1 from public.excavation_requests r where r.id = case_ai_assessments.request_id)
  );
drop policy if exists "Authorised staff create AI assessments" on public.case_ai_assessments;
create policy "Authorised staff create AI assessments"
  on public.case_ai_assessments for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (select 1 from public.profiles p where p.id = (select auth.uid())
      and (p.role in ('admin','coordinator')
        or (p.role = 'department' and public.is_department_assigned_to_request(case_ai_assessments.request_id))))
    and exists (select 1 from public.excavation_requests r where r.id = case_ai_assessments.request_id)
  );
grant select, insert on public.case_ai_assessments to authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('samanvay-case-evidence','samanvay-case-evidence',false,20971520,
  array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public=false, file_size_limit=20971520,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'];

drop policy if exists "SAMANVAY evidence upload by case participants" on storage.objects;
create policy "SAMANVAY evidence upload by case participants"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'samanvay-case-evidence'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and exists (select 1 from public.excavation_requests r where r.id::text = (storage.foldername(name))[1])
  );
drop policy if exists "SAMANVAY evidence read through case permissions" on storage.objects;
create policy "SAMANVAY evidence read through case permissions"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'samanvay-case-evidence'
    and exists (select 1 from public.case_attachments a where a.storage_path = storage.objects.name)
  );

create or replace function public.samanvay_notify_assignment()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_requester_id uuid; v_department_name text;
begin
  select r.requester_id,d.name into v_requester_id,v_department_name
  from public.excavation_requests r join public.departments d on d.id=new.department_id
  where r.id=new.request_id;
  if v_requester_id is not null then
    insert into public.user_notifications(recipient_id,request_id,notification_type,title,body,data)
    values(v_requester_id,new.request_id,'assignment','Department assigned',
      coalesce(v_department_name,'A department') || ' has been assigned to your case.',
      jsonb_build_object('review_id',new.id,'department_id',new.department_id));
  end if;
  insert into public.user_notifications(recipient_id,request_id,notification_type,title,body,data)
  select p.id,new.request_id,'assignment','New case assigned',
    'A case has been assigned to your department for technical review.',
    jsonb_build_object('review_id',new.id,'department_id',new.department_id)
  from public.profiles p where p.role='department' and p.department_id=new.department_id;
  return new;
end;
$$;

create or replace function public.samanvay_notify_review_update()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_requester_id uuid; v_department_name text;
begin
  if new.review_status is not distinct from old.review_status then return new; end if;
  select r.requester_id,d.name into v_requester_id,v_department_name
  from public.excavation_requests r join public.departments d on d.id=new.department_id
  where r.id=new.request_id;
  if v_requester_id is not null then
    insert into public.user_notifications(recipient_id,request_id,notification_type,title,body,data)
    values(v_requester_id,new.request_id,'review','Department review updated',
      coalesce(v_department_name,'A department') || ' updated its review to ' ||
        replace(new.review_status,'_',' ') || '.',
      jsonb_build_object('review_id',new.id,'review_status',new.review_status));
  end if;
  return new;
end;
$$;

create or replace function public.samanvay_notify_status_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_requester_id uuid;
begin
  select requester_id into v_requester_id from public.excavation_requests where id=new.request_id;
  if v_requester_id is not null and v_requester_id is distinct from new.changed_by then
    insert into public.user_notifications(recipient_id,request_id,notification_type,title,body,data)
    values(v_requester_id,new.request_id,'status','Case status changed',
      'Your case status is now ' || replace(new.new_status,'_',' ') || '.',
      jsonb_build_object('new_status',new.new_status));
  end if;
  return new;
end;
$$;

create or replace function public.samanvay_notify_case_message()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.user_notifications(recipient_id,request_id,notification_type,title,body,data)
  select distinct targets.recipient_id,new.request_id,'message','New case message',
    left(new.body,140),jsonb_build_object('message_id',new.id)
  from (
    select r.requester_id as recipient_id from public.excavation_requests r
      where r.id=new.request_id and r.requester_id <> new.sender_id
    union
    select p.id from public.request_department_reviews d
      join public.profiles p on p.department_id=d.department_id
      where d.request_id=new.request_id and p.role='department' and p.id<>new.sender_id
    union
    select p.id from public.profiles p where p.role in ('admin','coordinator') and p.id<>new.sender_id
  ) targets where targets.recipient_id is not null;
  return new;
end;
$$;

drop trigger if exists samanvay_notify_assignment on public.request_department_reviews;
create trigger samanvay_notify_assignment after insert on public.request_department_reviews
  for each row execute function public.samanvay_notify_assignment();
drop trigger if exists samanvay_notify_review_update on public.request_department_reviews;
create trigger samanvay_notify_review_update after update of review_status on public.request_department_reviews
  for each row execute function public.samanvay_notify_review_update();
drop trigger if exists samanvay_notify_status_change on public.request_status_history;
create trigger samanvay_notify_status_change after insert on public.request_status_history
  for each row execute function public.samanvay_notify_status_change();
drop trigger if exists samanvay_notify_case_message on public.case_messages;
create trigger samanvay_notify_case_message after insert on public.case_messages
  for each row execute function public.samanvay_notify_case_message();

revoke all on function public.samanvay_notify_assignment() from public,anon,authenticated;
revoke all on function public.samanvay_notify_review_update() from public,anon,authenticated;
revoke all on function public.samanvay_notify_status_change() from public,anon,authenticated;
revoke all on function public.samanvay_notify_case_message() from public,anon,authenticated;
revoke all on function public.handle_new_user() from public,anon,authenticated;
revoke all on function public.rls_auto_enable() from public,anon,authenticated;

do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='case_messages') then
      execute 'alter publication supabase_realtime add table public.case_messages';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='user_notifications') then
      execute 'alter publication supabase_realtime add table public.user_notifications';
    end if;
  end if;
end;
$$;
