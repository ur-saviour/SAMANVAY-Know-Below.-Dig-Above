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
  coalesce(ev.evidence_count,0::bigint)::integer as evidence_count,
  a.created_at,
  a.import_run_id,
  r.source_title,
  r.source_organisation,
  r.authorization_reference,
  r.source_url,
  r.status as import_status,
  coalesce(ev.evidence_reference_items,'[]'::jsonb) as evidence_reference_items
from gis.underground_assets a
left join public.departments d on d.id=a.owner_department_id
left join (
  select
    e.asset_id,
    count(*) as evidence_count,
    coalesce(
      jsonb_agg(jsonb_build_object(
        'survey_method',e.survey_method,
        'survey_date',e.survey_date,
        'surveyor_organisation',e.surveyor_organisation,
        'evidence_reference_code',e.evidence_reference_code,
        'evidence_sha256',e.evidence_sha256,
        'created_at',e.created_at
      ) order by e.created_at desc)
      filter (where e.evidence_reference_code is not null and e.evidence_sha256 is not null),
      '[]'::jsonb
    ) as evidence_reference_items
  from gis.asset_survey_evidence e
  group by e.asset_id
) ev on ev.asset_id=a.id
left join public.utility_geometry_import_runs r on r.id=a.import_run_id
where exists (
  select 1 from public.profiles p
  where p.id=(select auth.uid())
    and p.role=any(array['admin'::text,'coordinator'::text])
);
