create index if not exists excavation_requests_road_schedule_idx
  on public.excavation_requests (
    lower(btrim(city)),
    lower(btrim(road_name)),
    planned_start_date,
    planned_end_date
  )
  where planned_start_date is not null and planned_end_date is not null;

create or replace view public.road_work_schedule_advisories
with (security_invoker = true)
as
select
  r.id as request_id,
  r.request_number,
  r.title,
  r.road_name,
  r.city,
  r.case_category,
  r.work_activity,
  r.status,
  r.department_id,
  d.name as department_name,
  r.planned_start_date,
  r.planned_end_date,
  coalesce(ov.overlap_count, 0) as overlap_count,
  coalesce(ov.overlapping_request_numbers, array[]::bigint[]) as overlapping_request_numbers,
  case
    when r.planned_start_date is null or r.planned_end_date is null then 'dates_missing'
    when r.planned_end_date < r.planned_start_date then 'invalid_window'
    when coalesce(ov.overlap_count, 0) > 0 then 'road_window_overlap'
    when r.status in ('completed','rejected') then 'closed'
    when r.planned_end_date < current_date then 'past_due'
    when r.planned_start_date <= current_date and r.planned_end_date >= current_date then 'in_window'
    else 'scheduled'
  end as schedule_state,
  case when r.planned_start_date is null then null
       else r.planned_start_date - current_date end as days_until_start
from public.excavation_requests r
left join public.departments d on d.id = r.department_id
left join lateral (
  select
    count(*)::integer as overlap_count,
    array_agg(other.request_number order by other.planned_start_date, other.request_number) as overlapping_request_numbers
  from public.excavation_requests other
  where other.id <> r.id
    and lower(btrim(other.city)) = lower(btrim(r.city))
    and lower(btrim(other.road_name)) = lower(btrim(r.road_name))
    and other.planned_start_date is not null
    and other.planned_end_date is not null
    and r.planned_start_date is not null
    and r.planned_end_date is not null
    and other.planned_start_date <= r.planned_end_date
    and other.planned_end_date >= r.planned_start_date
    and other.status not in ('rejected','completed')
    and r.status not in ('rejected','completed')
) ov on true;

revoke all on public.road_work_schedule_advisories from anon, public;
grant select on public.road_work_schedule_advisories to authenticated;
