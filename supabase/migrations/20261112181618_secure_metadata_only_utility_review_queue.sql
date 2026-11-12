-- Keep the client-facing review queue metadata-only without a SECURITY DEFINER view.
-- The private function performs the reviewer-role check using the caller JWT identity,
-- then returns only the explicit projection required by the verification queue.

create or replace function private.get_utility_asset_verification_queue()
returns table (
  asset_id uuid,
  asset_type text,
  owner_department text,
  operational_status text,
  source_type text,
  verification_status text,
  surveyed_at timestamptz,
  surveyed_by_org text,
  verified_at timestamptz,
  verification_notes text,
  evidence_count integer,
  created_at timestamptz,
  import_run_id uuid,
  source_title text,
  source_organisation text,
  authorization_reference text,
  source_url text,
  import_status text,
  evidence_reference_items jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null
     or not exists (
       select 1
       from public.profiles p
       where p.id = (select auth.uid())
         and p.role in ('admin', 'coordinator')
     ) then
    raise exception 'Administrator or coordinator access required';
  end if;

  return query
  select
    a.id,
    a.asset_type,
    d.name,
    a.operational_status,
    a.source_type,
    a.verification_status,
    a.surveyed_at,
    a.surveyed_by_org,
    a.verified_at,
    a.verification_notes,
    coalesce(ev.evidence_count, 0::bigint)::integer,
    a.created_at,
    a.import_run_id,
    r.source_title,
    r.source_organisation,
    r.authorization_reference,
    r.source_url,
    r.status,
    coalesce(ev.evidence_reference_items, '[]'::jsonb)
  from gis.underground_assets a
  left join public.departments d on d.id = a.owner_department_id
  left join (
    select
      e.asset_id,
      count(*) as evidence_count,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'survey_method', e.survey_method,
            'survey_date', e.survey_date,
            'surveyor_organisation', e.surveyor_organisation,
            'evidence_reference_code', e.evidence_reference_code,
            'evidence_sha256', e.evidence_sha256,
            'created_at', e.created_at
          )
          order by e.created_at desc
        ) filter (
          where e.evidence_reference_code is not null
            and e.evidence_sha256 is not null
        ),
        '[]'::jsonb
      ) as evidence_reference_items
    from gis.asset_survey_evidence e
    group by e.asset_id
  ) ev on ev.asset_id = a.id
  left join public.utility_geometry_import_runs r on r.id = a.import_run_id;
end;
$function$;

revoke all on function private.get_utility_asset_verification_queue()
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.get_utility_asset_verification_queue()
  to authenticated;

create or replace view public.utility_asset_verification_queue
with (security_invoker = true, security_barrier = true)
as
select *
from private.get_utility_asset_verification_queue();

revoke all privileges on table public.utility_asset_verification_queue
  from public, anon, authenticated;
grant select on table public.utility_asset_verification_queue
  to authenticated;

comment on function private.get_utility_asset_verification_queue() is
  'Private role-gated definer function backing the metadata-only utility asset review queue.';
comment on view public.utility_asset_verification_queue is
  'Metadata-only utility asset review queue. Only admin/coordinator profiles can read it; exact geometry is never returned.';
