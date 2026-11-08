alter table gis.asset_survey_evidence
  add column if not exists evidence_reference_code text,
  add column if not exists evidence_sha256 text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='gis.asset_survey_evidence'::regclass
      and conname='asset_survey_evidence_reference_hash_pair'
  ) then
    alter table gis.asset_survey_evidence
      add constraint asset_survey_evidence_reference_hash_pair
      check (
        (evidence_reference_code is null and evidence_sha256 is null)
        or
        (
          evidence_reference_code is not null
          and char_length(btrim(evidence_reference_code)) between 3 and 120
          and evidence_sha256 is not null
          and evidence_sha256 ~ '^[0-9a-f]{64}$'
        )
      );
  end if;
end $$;

create unique index if not exists asset_survey_evidence_reference_per_asset_uq
  on gis.asset_survey_evidence(asset_id, lower(evidence_reference_code))
  where evidence_reference_code is not null;

create or replace function public.list_department_asset_evidence_queue_server(
  p_actor_id uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_role text; v_department_id uuid; v_items jsonb;
begin
  select p.role,p.department_id into v_role,v_department_id
  from public.profiles p where p.id=p_actor_id;
  if v_role <> 'department' or v_department_id is null then
    raise exception 'Assigned department account required';
  end if;
  select coalesce(jsonb_agg(q.item order by q.created_at desc),'[]'::jsonb)
    into v_items
  from (
    select a.created_at,
      jsonb_build_object(
        'asset_id',a.id,'asset_type',a.asset_type,
        'verification_status',a.verification_status,'created_at',a.created_at,
        'evidence_count',ev.evidence_count,'evidence',ev.evidence_items
      ) as item
    from gis.underground_assets a
    left join lateral (
      select count(*)::integer as evidence_count,
        coalesce(jsonb_agg(jsonb_build_object(
          'survey_method',e.survey_method,'survey_date',e.survey_date,
          'surveyor_organisation',e.surveyor_organisation,
          'evidence_reference_code',e.evidence_reference_code,
          'evidence_sha256',e.evidence_sha256,'notes',e.notes,
          'created_at',e.created_at
        ) order by e.created_at desc),'[]'::jsonb) as evidence_items
      from gis.asset_survey_evidence e where e.asset_id=a.id
    ) ev on true
    where a.owner_department_id=v_department_id
      and a.import_run_id is not null
      and a.verification_status in ('unverified','field_surveyed','owner_confirmed','disputed')
    order by a.created_at desc limit 200
  ) q;
  return v_items;
end;
$$;

create or replace function public.register_asset_survey_evidence_server(
  p_actor_id uuid,p_asset_id uuid,p_survey_method text,p_survey_date date,
  p_surveyor_organisation text,p_evidence_reference_code text,
  p_evidence_sha256 text,p_notes text default null
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_role text; v_department_id uuid; v_owner_department_id uuid;
  v_run_id uuid; v_status text; v_id uuid;
begin
  select p.role,p.department_id into v_role,v_department_id
  from public.profiles p where p.id=p_actor_id;
  if v_role <> 'department' or v_department_id is null then
    raise exception 'Assigned department account required';
  end if;
  if p_survey_method not in (
    'ground_penetrating_radar','electromagnetic_locator','gnss_survey',
    'as_built_review','manual_inspection','other'
  ) then raise exception 'Unsupported survey method'; end if;
  if p_survey_date is null or p_survey_date > current_date then
    raise exception 'A valid survey date not later than today is required';
  end if;
  if p_surveyor_organisation is null
     or char_length(btrim(p_surveyor_organisation)) not between 3 and 200 then
    raise exception 'Surveyor organisation must contain 3 to 200 characters';
  end if;
  if p_evidence_reference_code is null
     or btrim(p_evidence_reference_code) !~ '^[A-Za-z0-9][A-Za-z0-9._/-]{2,119}$' then
    raise exception 'Evidence reference code is invalid';
  end if;
  if p_evidence_sha256 is null
     or lower(btrim(p_evidence_sha256)) !~ '^[0-9a-f]{64}$' then
    raise exception 'A valid SHA-256 checksum is required';
  end if;
  if p_notes is not null and char_length(p_notes) > 1000 then
    raise exception 'Evidence notes must not exceed 1000 characters';
  end if;

  select a.owner_department_id,a.import_run_id,a.verification_status
    into v_owner_department_id,v_run_id,v_status
  from gis.underground_assets a where a.id=p_asset_id for update;
  if not found then raise exception 'Asset submission not found'; end if;
  if v_owner_department_id is distinct from v_department_id then
    raise exception 'Asset belongs to another department';
  end if;
  if v_run_id is null then raise exception 'Asset has no provenance audit run'; end if;
  if v_status not in ('unverified','field_surveyed','owner_confirmed','disputed') then
    raise exception 'Asset is not accepting additional survey evidence';
  end if;
  if not exists (
    select 1 from public.utility_geometry_import_runs r
    where r.id=v_run_id and r.owner_department_id=v_department_id
      and r.status in ('imported_pending_review','partially_imported')
  ) then raise exception 'Import run is not eligible for evidence submission'; end if;

  insert into gis.asset_survey_evidence(
    asset_id,survey_method,survey_date,surveyor_organisation,
    evidence_reference_code,evidence_sha256,evidence_storage_path,notes,recorded_by
  ) values (
    p_asset_id,p_survey_method,p_survey_date,btrim(p_surveyor_organisation),
    btrim(p_evidence_reference_code),lower(btrim(p_evidence_sha256)),null,
    nullif(btrim(coalesce(p_notes,'')),''),p_actor_id
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.list_department_asset_evidence_queue_server(uuid) from public,anon,authenticated;
grant execute on function public.list_department_asset_evidence_queue_server(uuid) to service_role;
revoke all on function public.register_asset_survey_evidence_server(uuid,uuid,text,date,text,text,text,text) from public,anon,authenticated;
grant execute on function public.register_asset_survey_evidence_server(uuid,uuid,text,date,text,text,text,text) to service_role;

create or replace function public.review_underground_asset_submission(
  p_actor_id uuid,p_asset_id uuid,p_decision text,p_rationale text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_role text; v_status text; v_run_id uuid; v_evidence_count integer; v_result text;
begin
  if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject'; end if;
  if p_rationale is null or char_length(btrim(p_rationale)) < 10 or char_length(p_rationale) > 2000 then
    raise exception 'A review rationale of 10 to 2000 characters is required';
  end if;
  select role into v_role from public.profiles where id=p_actor_id;
  if v_role not in ('admin','coordinator') then raise exception 'Only an administrator or coordinator may review submissions'; end if;
  select a.verification_status,a.import_run_id into v_status,v_run_id
  from gis.underground_assets a where a.id=p_asset_id for update;
  if not found then raise exception 'Asset submission not found'; end if;
  if v_run_id is null then raise exception 'Asset is not linked to a provenance audit run'; end if;
  if v_status not in ('unverified','field_surveyed','owner_confirmed','disputed') then
    raise exception 'Asset is not in a reviewable state';
  end if;
  if not exists (select 1 from public.utility_geometry_import_runs r
    where r.id=v_run_id and r.status in ('imported_pending_review','partially_imported')) then
    raise exception 'Import run is not eligible for review';
  end if;
  select count(*)::integer into v_evidence_count from gis.asset_survey_evidence e
  where e.asset_id=p_asset_id and e.evidence_reference_code is not null and e.evidence_sha256 is not null;
  if p_decision='approve' then
    if v_evidence_count < 1 then raise exception 'Evidence reference and checksum are required before acceptance'; end if;
    -- Evidence acceptance is not a verification or map-publication decision.
    v_result := case when v_status='owner_confirmed' then 'owner_confirmed' else 'field_surveyed' end;
    update gis.underground_assets set verification_status=v_result,verified_by=null,
      verified_at=null,verification_notes=btrim(p_rationale),updated_at=now() where id=p_asset_id;
  else
    v_result := 'disputed';
    update gis.underground_assets set verification_status='disputed',verified_by=null,
      verified_at=null,verification_notes=btrim(p_rationale),updated_at=now() where id=p_asset_id;
  end if;
  insert into public.utility_asset_review_events(
    asset_id,import_run_id,reviewed_by,decision,rationale,evidence_count,previous_status,resulting_status
  ) values (p_asset_id,v_run_id,p_actor_id,p_decision,btrim(p_rationale),v_evidence_count,v_status,v_result);
  return jsonb_build_object('ok',true,'decision',p_decision,'resulting_status',v_result,
    'evidence_count',v_evidence_count,'review_event_recorded',true,'is_verified',false,
    'map_visibility','restricted_pending_owner_verification');
end;
$$;
revoke all on function public.review_underground_asset_submission(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_underground_asset_submission(uuid,uuid,text,text) to service_role;
