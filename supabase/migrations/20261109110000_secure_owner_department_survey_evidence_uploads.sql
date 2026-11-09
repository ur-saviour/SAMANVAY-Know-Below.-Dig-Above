create or replace function public.can_access_utility_asset_evidence_path(
  p_asset_id text,
  p_actor_id uuid
) returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_asset_id is null or p_asset_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_actor_id is null then return false; end if;
  return exists (
    select 1 from public.profiles p
    join gis.underground_assets a on a.owner_department_id=p.department_id
    where p.id=p_actor_id and p.role='department'
      and a.id=p_asset_id::uuid and a.import_run_id is not null
  );
end;
$$;
revoke all on function public.can_access_utility_asset_evidence_path(text,uuid) from public,anon;
grant execute on function public.can_access_utility_asset_evidence_path(text,uuid) to authenticated,service_role;

drop policy if exists "SAMANVAY asset evidence upload by owner department" on storage.objects;
create policy "SAMANVAY asset evidence upload by owner department"
on storage.objects for insert to authenticated with check (
  bucket_id='samanvay-asset-survey-evidence'
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and public.can_access_utility_asset_evidence_path((storage.foldername(name))[1],(select auth.uid()))
);
drop policy if exists "SAMANVAY asset evidence read by owner department" on storage.objects;
create policy "SAMANVAY asset evidence read by owner department"
on storage.objects for select to authenticated using (
  bucket_id='samanvay-asset-survey-evidence'
  and public.can_access_utility_asset_evidence_path((storage.foldername(name))[1],(select auth.uid()))
);
drop policy if exists "SAMANVAY asset evidence delete by uploader" on storage.objects;
create policy "SAMANVAY asset evidence delete by uploader"
on storage.objects for delete to authenticated using (
  bucket_id='samanvay-asset-survey-evidence'
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and public.can_access_utility_asset_evidence_path((storage.foldername(name))[1],(select auth.uid()))
);

create or replace function public.register_asset_survey_evidence_with_file_server(
  p_actor_id uuid,p_asset_id uuid,p_survey_method text,p_survey_date date,
  p_surveyor_organisation text,p_evidence_reference_code text,p_evidence_sha256 text,
  p_storage_path text,p_notes text default null
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_role text; v_department_id uuid; v_owner_department_id uuid;
  v_run_id uuid; v_status text; v_id uuid; v_object_size bigint; v_mime text;
begin
  select p.role,p.department_id into v_role,v_department_id
  from public.profiles p where p.id=p_actor_id;
  if v_role <> 'department' or v_department_id is null then raise exception 'Assigned department account required'; end if;
  if p_survey_method not in ('ground_penetrating_radar','electromagnetic_locator','gnss_survey','as_built_review','manual_inspection','other') then raise exception 'Unsupported survey method'; end if;
  if p_survey_date is null or p_survey_date > current_date then raise exception 'A valid survey date not later than today is required'; end if;
  if p_surveyor_organisation is null or char_length(btrim(p_surveyor_organisation)) not between 3 and 200 then raise exception 'Surveyor organisation must contain 3 to 200 characters'; end if;
  if p_evidence_reference_code is null or btrim(p_evidence_reference_code) !~ '^[A-Za-z0-9][A-Za-z0-9._/-]{2,119}$' then raise exception 'Evidence reference code is invalid'; end if;
  if p_evidence_sha256 is null or lower(btrim(p_evidence_sha256)) !~ '^[0-9a-f]{64}$' then raise exception 'A valid SHA-256 checksum is required'; end if;
  if p_notes is not null and char_length(p_notes)>1000 then raise exception 'Evidence notes must not exceed 1000 characters'; end if;
  if p_storage_path is null or p_storage_path !~ ('^'||p_asset_id::text||'/'||p_actor_id::text||'/[A-Za-z0-9._-]{1,180}\.(pdf|jpg|jpeg|png|webp)$') then raise exception 'Evidence file path is invalid'; end if;
  select a.owner_department_id,a.import_run_id,a.verification_status into v_owner_department_id,v_run_id,v_status
  from gis.underground_assets a where a.id=p_asset_id for update;
  if not found then raise exception 'Asset submission not found'; end if;
  if v_owner_department_id is distinct from v_department_id then raise exception 'Asset belongs to another department'; end if;
  if v_run_id is null then raise exception 'Asset has no provenance audit run'; end if;
  if v_status not in ('unverified','field_surveyed','owner_confirmed','disputed') then raise exception 'Asset is not accepting additional survey evidence'; end if;
  if not exists (select 1 from public.utility_geometry_import_runs r where r.id=v_run_id and r.owner_department_id=v_department_id and r.status in ('imported_pending_review','partially_imported')) then raise exception 'Import run is not eligible for evidence submission'; end if;
  select (o.metadata->>'size')::bigint,o.metadata->>'mimetype' into v_object_size,v_mime
  from storage.objects o where o.bucket_id='samanvay-asset-survey-evidence' and o.name=p_storage_path;
  if not found then raise exception 'Evidence object is not present in private storage'; end if;
  if v_object_size is null or v_object_size<1 or v_object_size>20971520 then raise exception 'Evidence file size is outside the permitted limit'; end if;
  if v_mime not in ('application/pdf','image/jpeg','image/png','image/webp') then raise exception 'Evidence file type is not permitted'; end if;
  insert into gis.asset_survey_evidence(asset_id,survey_method,survey_date,surveyor_organisation,evidence_reference_code,evidence_sha256,evidence_storage_path,notes,recorded_by)
  values (p_asset_id,p_survey_method,p_survey_date,btrim(p_surveyor_organisation),btrim(p_evidence_reference_code),lower(btrim(p_evidence_sha256)),p_storage_path,nullif(btrim(coalesce(p_notes,'')),''),p_actor_id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.register_asset_survey_evidence_server(uuid,uuid,text,date,text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.register_asset_survey_evidence_with_file_server(uuid,uuid,text,date,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.register_asset_survey_evidence_with_file_server(uuid,uuid,text,date,text,text,text,text,text) to service_role;
