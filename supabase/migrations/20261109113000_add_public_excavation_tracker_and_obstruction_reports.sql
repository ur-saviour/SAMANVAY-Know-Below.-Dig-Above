-- Public tracker: source-backed published notices and private citizen reports.
-- This migration is additive. It does not alter utility geometry, GIS RLS, or evidence storage.

create table if not exists public.public_excavation_notices (
  id uuid primary key default gen_random_uuid(),
  notice_code text not null unique check (char_length(btrim(notice_code)) between 3 and 80),
  title text not null check (char_length(btrim(title)) between 5 and 240),
  notice_type text not null check (notice_type in ('work', 'no_dig')),
  summary text,
  city text not null check (char_length(btrim(city)) between 2 and 120),
  district text,
  ward_code text,
  area_label text,
  responsible_department_id uuid references public.departments(id) on delete restrict,
  responsible_department_name text not null check (char_length(btrim(responsible_department_name)) between 2 and 200),
  starts_on date not null,
  ends_on date,
  progress_percent smallint check (progress_percent between 0 and 100),
  notice_status text not null default 'draft'
    check (notice_status in ('draft', 'published', 'active', 'completed', 'cancelled')),
  source_reference text,
  source_url text,
  published_at timestamptz,
  published_by uuid references public.profiles(id) on delete restrict,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint public_excavation_notice_dates_check check (ends_on is null or ends_on >= starts_on),
  constraint public_excavation_notice_source_url_check check (
    source_url is null or source_url ~* '^https://'
  ),
  constraint public_excavation_notice_publication_check check (
    notice_status = 'draft'
    or (published_at is not null and published_by is not null
        and source_reference is not null and char_length(btrim(source_reference)) >= 3)
  )
);

create index if not exists public_excavation_notices_location_idx
  on public.public_excavation_notices(city, ward_code, published_at desc);
create index if not exists public_excavation_notices_status_date_idx
  on public.public_excavation_notices(notice_status, starts_on, ends_on);

alter table public.public_excavation_notices enable row level security;
grant select on public.public_excavation_notices to anon, authenticated;
grant insert, update on public.public_excavation_notices to authenticated;

drop policy if exists "Published SAMANVAY work notices are public" on public.public_excavation_notices;
create policy "Published SAMANVAY work notices are public"
  on public.public_excavation_notices for select to anon, authenticated
  using (notice_status <> 'draft' and published_at is not null);

drop policy if exists "Assigned staff can read draft notices" on public.public_excavation_notices;
create policy "Assigned staff can read draft notices"
  on public.public_excavation_notices for select to authenticated
  using (
    notice_status = 'draft'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = responsible_department_id))
    )
  );

drop policy if exists "Authorised staff create sourced work notices" on public.public_excavation_notices;
create policy "Authorised staff create sourced work notices"
  on public.public_excavation_notices for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = responsible_department_id))
    )
  );

drop policy if exists "Authorised staff update work notices" on public.public_excavation_notices;
create policy "Authorised staff update work notices"
  on public.public_excavation_notices for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = responsible_department_id))
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = responsible_department_id))
    )
  );

create table if not exists public.public_excavation_notice_events (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.public_excavation_notices(id) on delete cascade,
  event_type text not null check (event_type in (
    'published', 'work_started', 'progress_update', 'schedule_change',
    'work_paused', 'work_completed', 'notice_cancelled', 'no_dig_update'
  )),
  title text not null check (char_length(btrim(title)) between 3 and 180),
  details text,
  progress_percent smallint check (progress_percent between 0 and 100),
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index if not exists public_excavation_notice_events_timeline_idx
  on public.public_excavation_notice_events(notice_id, created_at desc);

alter table public.public_excavation_notice_events enable row level security;
grant select on public.public_excavation_notice_events to anon, authenticated;
grant insert on public.public_excavation_notice_events to authenticated;

drop policy if exists "Public can read events for published notices" on public.public_excavation_notice_events;
create policy "Public can read events for published notices"
  on public.public_excavation_notice_events for select to anon, authenticated
  using (exists (
    select 1 from public.public_excavation_notices n
    where n.id = notice_id and n.notice_status <> 'draft' and n.published_at is not null
  ));

drop policy if exists "Responsible staff add notice timeline events" on public.public_excavation_notice_events;
create policy "Responsible staff add notice timeline events"
  on public.public_excavation_notice_events for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1
      from public.public_excavation_notices n
      join public.profiles p on p.id = (select auth.uid())
      where n.id = notice_id
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = n.responsible_department_id))
    )
  );

create table if not exists public.public_obstruction_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete restrict,
  city text not null check (char_length(btrim(city)) between 2 and 120),
  district text,
  ward_code text,
  area_label text not null check (char_length(btrim(area_label)) between 2 and 200),
  report_type text not null check (report_type in (
    'road_obstruction', 'blocked_access', 'unmarked_work',
    'unsafe_excavation', 'possible_damage', 'other'
  )),
  details text not null check (char_length(btrim(details)) between 10 and 1500),
  assigned_department_id uuid references public.departments(id) on delete restrict,
  report_status text not null default 'submitted'
    check (report_status in ('submitted', 'acknowledged', 'in_progress', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists public_obstruction_reports_reporter_idx
  on public.public_obstruction_reports(reporter_id, created_at desc);
create index if not exists public_obstruction_reports_department_idx
  on public.public_obstruction_reports(assigned_department_id, report_status, created_at desc);

alter table public.public_obstruction_reports enable row level security;
grant select, insert on public.public_obstruction_reports to authenticated;
revoke update on public.public_obstruction_reports from authenticated;
grant update (assigned_department_id, report_status, updated_at)
  on public.public_obstruction_reports to authenticated;

drop policy if exists "Reporters and authorised reviewers read obstruction reports" on public.public_obstruction_reports;
create policy "Reporters and authorised reviewers read obstruction reports"
  on public.public_obstruction_reports for select to authenticated
  using (
    reporter_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = assigned_department_id))
    )
  );

drop policy if exists "Authenticated users submit their own obstruction reports" on public.public_obstruction_reports;
create policy "Authenticated users submit their own obstruction reports"
  on public.public_obstruction_reports for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and report_status = 'submitted'
    and assigned_department_id is null
  );

drop policy if exists "Assigned staff update obstruction reports" on public.public_obstruction_reports;
create policy "Assigned staff update obstruction reports"
  on public.public_obstruction_reports for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = assigned_department_id))
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and (p.role in ('admin', 'coordinator')
          or (p.role = 'department' and p.department_id is not null
              and p.department_id = assigned_department_id))
    )
  );

-- No public-obstruction-report delete policy is intentionally provided.
-- Existing underground-asset, owner-geometry and private evidence policies are untouched.
