create table if not exists public.utility_asset_review_events (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references gis.underground_assets(id) on delete restrict,
  import_run_id uuid not null references public.utility_geometry_import_runs(id) on delete restrict,
  reviewed_by uuid not null references public.profiles(id) on delete restrict,
  decision text not null check (decision in ('approve','reject')),
  rationale text not null check (char_length(btrim(rationale)) between 10 and 2000),
  evidence_count integer not null check (evidence_count >= 0),
  previous_status text not null,
  resulting_status text not null,
  created_at timestamptz not null default now()
);
alter table public.utility_asset_review_events enable row level security;
revoke all on public.utility_asset_review_events from public, anon, authenticated;
grant select, insert on public.utility_asset_review_events to service_role;
create index if not exists utility_asset_review_events_asset_created_idx
  on public.utility_asset_review_events(asset_id, created_at desc);

create or replace function public.review_underground_asset_submission(
  p_actor_id uuid, p_asset_id uuid, p_decision text, p_rationale text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_role text; v_status text; v_run_id uuid; v_source_type text;
  v_evidence_count integer; v_result text;
begin
  if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject'; end if;
  if p_rationale is null or char_length(btrim(p_rationale)) < 10 or char_length(p_rationale) > 2000 then
    raise exception 'A review rationale of 10 to 2000 characters is required';
  end if;
  select role into v_role from public.profiles where id = p_actor_id;
  if v_role not in ('admin','coordinator') then raise exception 'Only an administrator or coordinator may review submissions'; end if;
  select a.verification_status,a.import_run_id,a.source_type
    into v_status,v_run_id,v_source_type
  from gis.underground_assets a where a.id=p_asset_id for update;
  if not found then raise exception 'Asset submission not found'; end if;
  if v_run_id is null then raise exception 'Asset is not linked to a provenance audit run'; end if;
  if v_status not in ('unverified','field_surveyed','owner_confirmed','disputed') then raise exception 'Asset is not in a reviewable state'; end if;
  if not exists (select 1 from public.utility_geometry_import_runs r
    where r.id=v_run_id and r.status in ('imported_pending_review','partially_imported')) then
    raise exception 'Import run is not eligible for review';
  end if;
  select count(*)::integer into v_evidence_count from gis.asset_survey_evidence e where e.asset_id=p_asset_id;
  if p_decision='approve' then
    if v_evidence_count < 1 then raise exception 'Approval requires at least one recorded survey evidence item'; end if;
    if v_source_type not in ('utility_owner','field_survey','as_built_drawing') then raise exception 'Unsupported source type for approval'; end if;
    v_result := 'verified';
    update gis.underground_assets set verification_status='verified',verified_by=p_actor_id,
      verified_at=now(),verification_notes=btrim(p_rationale),updated_at=now() where id=p_asset_id;
  else
    v_result := 'disputed';
    update gis.underground_assets set verification_status='disputed',verified_by=null,
      verified_at=null,verification_notes=btrim(p_rationale),updated_at=now() where id=p_asset_id;
  end if;
  insert into public.utility_asset_review_events(asset_id,import_run_id,reviewed_by,decision,rationale,
    evidence_count,previous_status,resulting_status)
  values (p_asset_id,v_run_id,p_actor_id,p_decision,btrim(p_rationale),v_evidence_count,v_status,v_result);
  return jsonb_build_object('ok',true,'decision',p_decision,'resulting_status',v_result,
    'evidence_count',v_evidence_count,'review_event_recorded',true);
end;
$$;
revoke all on function public.review_underground_asset_submission(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_underground_asset_submission(uuid,uuid,text,text) to service_role;
