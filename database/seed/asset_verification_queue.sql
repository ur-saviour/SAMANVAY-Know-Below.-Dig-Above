-- SAMANVAY restricted metadata-only asset verification queue.
-- Deliberately excludes geometry, coordinates, depth, dimensions and positional accuracy.
-- Access is restricted to authenticated admin/coordinator profiles.

create or replace view public.utility_asset_verification_queue
with (security_barrier = true)
as
select
  a.id as asset_id,
  a.asset_type,
  d.name as owner_department,
  a.operational_status,
  a.source_type,
  a.verification_status,
  a.surveyed_at,
  a.surveyed_by_org,
  a.verified_at,
  a.verification_notes,
  coalesce(ev.evidence_count,0)::integer as evidence_count,
  a.created_at
from gis.underground_assets a
left join public.departments d on d.id=a.owner_department_id
left join (
  select asset_id,count(*) as evidence_count
  from gis.asset_survey_evidence
  group by asset_id
) ev on ev.asset_id=a.id
where exists (
  select 1 from public.profiles p
  where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
);

revoke all on public.utility_asset_verification_queue from public, anon;
grant select on public.utility_asset_verification_queue to authenticated;

create index if not exists asset_survey_evidence_asset_id_idx
on gis.asset_survey_evidence(asset_id);
