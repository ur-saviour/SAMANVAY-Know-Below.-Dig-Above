alter table public.utility_asset_review_events
  drop constraint if exists utility_asset_review_events_decision_check;
alter table public.utility_asset_review_events
  add constraint utility_asset_review_events_decision_check
  check (decision in ('accept_evidence','reject'));

create or replace function public.review_underground_asset_submission(
  p_actor_id uuid,p_asset_id uuid,p_decision text,p_rationale text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_role text; v_status text; v_run_id uuid; v_evidence_count integer; v_result text;
begin
  if p_decision not in ('accept_evidence','reject') then raise exception 'Decision must be accept_evidence or reject'; end if;
  if p_rationale is null or char_length(btrim(p_rationale))<10 or char_length(p_rationale)>2000 then
    raise exception 'A review rationale of 10 to 2000 characters is required';
  end if;
  select role into v_role from public.profiles where id=p_actor_id;
  if v_role not in ('admin','coordinator') then raise exception 'Only an administrator or coordinator may review submissions'; end if;
  select a.verification_status,a.import_run_id into v_status,v_run_id
    from gis.underground_assets a where a.id=p_asset_id for update;
  if not found then raise exception 'Asset submission not found'; end if;
  if v_run_id is null then raise exception 'Asset is not linked to a provenance audit run'; end if;
  if v_status not in ('unverified','field_surveyed','owner_confirmed','disputed') then raise exception 'Asset is not in a reviewable state'; end if;
  if not exists(select 1 from public.utility_geometry_import_runs r where r.id=v_run_id and r.status in ('imported_pending_review','partially_imported')) then
    raise exception 'Import run is not eligible for review';
  end if;
  select count(*)::integer into v_evidence_count from gis.asset_survey_evidence e where e.asset_id=p_asset_id;
  if p_decision='accept_evidence' then
    if v_evidence_count<1 then raise exception 'Evidence acceptance requires at least one recorded survey evidence item'; end if;
    v_result:='evidence_accepted_pending_owner_verification';
  else
    v_result:='disputed';
    update gis.underground_assets set verification_status='disputed',verified_by=null,verified_at=null,
      verification_notes=btrim(p_rationale),updated_at=now() where id=p_asset_id;
  end if;
  insert into public.utility_asset_review_events(asset_id,import_run_id,reviewed_by,decision,rationale,evidence_count,previous_status,resulting_status)
  values(p_asset_id,v_run_id,p_actor_id,p_decision,btrim(p_rationale),v_evidence_count,v_status,v_result);
  return jsonb_build_object('ok',true,'decision',p_decision,'resulting_status',v_result,
    'asset_verification_status',case when p_decision='accept_evidence' then v_status else 'disputed' end,
    'evidence_count',v_evidence_count,'review_event_recorded',true,'geometry_verified',false);
end;
$$;
revoke all on function public.review_underground_asset_submission(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_underground_asset_submission(uuid,uuid,text,text) to service_role;