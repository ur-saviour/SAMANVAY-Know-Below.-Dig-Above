-- Explicitly remove project-wide default grants from the tracker tables.
-- Public users can read published notices and timelines only. Obstruction reports
-- are not exposed to anon; authenticated updates are limited to review fields.

revoke all on table public.public_excavation_notices from public, anon, authenticated;
revoke all on table public.public_excavation_notice_events from public, anon, authenticated;
revoke all on table public.public_obstruction_reports from public, anon, authenticated;

grant select on table public.public_excavation_notices to anon, authenticated;
grant select on table public.public_excavation_notice_events to anon, authenticated;
grant insert, update on table public.public_excavation_notices to authenticated;
grant insert on table public.public_excavation_notice_events to authenticated;

grant select, insert on table public.public_obstruction_reports to authenticated;
grant update (assigned_department_id, report_status, updated_at)
  on table public.public_obstruction_reports to authenticated;
