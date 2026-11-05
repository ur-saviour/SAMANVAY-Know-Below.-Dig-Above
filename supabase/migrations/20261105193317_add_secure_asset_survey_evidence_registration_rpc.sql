create or replace function public.record_asset_survey_evidence(
  p_asset_id uuid,p_survey_method text,p_survey_date date,
  p_horizontal_accuracy_m numeric default null,p_vertical_accuracy_m numeric default null,
  p_surveyor_organisation text default null,p_evidence_storage_path text default null,
  p_notes text default null
)
returns uuid language plpgsql security invoker set search_path=''
as $function$
declare v_id uuid;
begin
  if p_survey_method not in ('ground_penetrating_radar','electromagnetic_locator','gnss_survey','as_built_review','manual_inspection','other') then
    raise exception 'Unsupported survey method';
  end if;
  if p_survey_date is null then raise exception 'Survey date is required'; end if;
  if p_horizontal_accuracy_m is not null and (p_horizontal_accuracy_m<0 or p_horizontal_accuracy_m>1000) then
    raise exception 'Horizontal accuracy must be between 0 and 1000 metres';
  end if;
  if p_vertical_accuracy_m is not null and (p_vertical_accuracy_m<0 or p_vertical_accuracy_m>1000) then
    raise exception 'Vertical accuracy must be between 0 and 1000 metres';
  end if;
  if p_evidence_storage_path is not null and
    p_evidence_storage_path not like p_asset_id::text || '/' || (select auth.uid())::text || '/%' then
    raise exception 'Evidence path must be inside this asset and uploader folder';
  end if;
  insert into gis.asset_survey_evidence(
    asset_id,survey_method,survey_date,horizontal_accuracy_m,vertical_accuracy_m,
    surveyor_organisation,evidence_storage_path,notes,recorded_by
  ) values (
    p_asset_id,p_survey_method,p_survey_date,p_horizontal_accuracy_m,p_vertical_accuracy_m,
    p_surveyor_organisation,p_evidence_storage_path,p_notes,(select auth.uid())
  ) returning id into v_id;
  return v_id;
end;
$function$;
revoke all on function public.record_asset_survey_evidence(uuid,text,date,numeric,numeric,text,text,text) from public,anon;
grant execute on function public.record_asset_survey_evidence(uuid,text,date,numeric,numeric,text,text,text) to authenticated;
