-- Enforce consistency between each asset's provenance and its audit run.
-- The submitter's source declaration is checked again at the database boundary.

create or replace function public.register_underground_assets_batch_server(
  p_actor_id uuid,
  p_assets jsonb,
  p_import_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_asset jsonb;
  v_props jsonb;
  v_geometry jsonb;
  v_code text;
  v_id uuid;
  v_error text;
  v_index integer := 0;
  v_imported integer := 0;
  v_failed integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_department_id uuid;
  v_run_department_id uuid;
  v_run_source_type text;
  v_run_authorization_reference text;
  v_run_source_organisation text;
begin
  if p_actor_id is null then
    raise exception 'Authenticated actor is required';
  end if;

  select p.department_id into v_department_id
  from public.profiles p
  where p.id = p_actor_id and p.role = 'department';

  if v_department_id is null then
    raise exception 'Only an assigned department account can register assets';
  end if;

  select r.owner_department_id, r.source_type, r.authorization_reference, r.source_organisation
    into v_run_department_id, v_run_source_type, v_run_authorization_reference, v_run_source_organisation
  from public.utility_geometry_import_runs r
  where r.id = p_import_run_id
    and r.requested_by = p_actor_id
    and r.status = 'importing';

  if v_run_department_id is distinct from v_department_id then
    raise exception 'Import run is missing, closed or owned by another department';
  end if;

  if p_assets is null or jsonb_typeof(p_assets) <> 'array' then
    raise exception 'An array of GeoJSON features is required';
  end if;
  if jsonb_array_length(p_assets) < 1 or jsonb_array_length(p_assets) > 500 then
    raise exception 'Batch must contain 1 to 500 features';
  end if;

  for v_asset in select value from jsonb_array_elements(p_assets)
  loop
    v_index := v_index + 1;
    v_props := case when jsonb_typeof(v_asset->'properties') = 'object' then v_asset->'properties' else '{}'::jsonb end;
    v_geometry := v_asset->'geometry';
    v_code := coalesce(nullif(btrim(v_props->>'asset_code'), ''), 'feature_' || v_index::text);

    begin
      if v_props->>'source_type' is distinct from v_run_source_type
         or v_props->>'source_reference' is distinct from v_run_authorization_reference
         or v_props->>'surveyed_by_org' is distinct from v_run_source_organisation then
        raise exception 'Feature provenance does not match the authorised import audit run';
      end if;
      if v_run_source_type not in ('utility_owner','field_survey','as_built_drawing') then
        raise exception 'Unsupported owner-authorised source category';
      end if;
      if v_run_source_type='field_survey'
         and nullif(btrim(coalesce(v_props->>'surveyed_at','')),'') is null then
        raise exception 'Field survey date is required';
      end if;

      v_id := public.register_underground_asset_server(
        p_actor_id,
        v_props->>'asset_code',
        v_props->>'asset_name',
        v_props->>'asset_type',
        v_geometry,
        v_run_source_type,
        v_run_authorization_reference,
        nullif(v_props->>'depth_m','')::numeric,
        nullif(v_props->>'horizontal_accuracy_m','')::numeric,
        nullif(v_props->>'vertical_accuracy_m','')::numeric,
        v_props->>'material',
        nullif(v_props->>'diameter_mm','')::numeric,
        nullif(v_props->>'surveyed_at','')::timestamptz,
        v_run_source_organisation,
        null
      );

      update gis.underground_assets
      set import_run_id=p_import_run_id
      where id=v_id and created_by=p_actor_id;
      if not found then
        raise exception 'Asset provenance link could not be recorded';
      end if;

      v_imported := v_imported + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'asset_code', v_code, 'id', v_id
      ));
    exception when others then
      v_failed := v_failed + 1;
      v_error := sqlerrm;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'asset_code', v_code, 'error', left(v_error, 180)
      ));
    end;
  end loop;

  return jsonb_build_object(
    'received', v_index,
    'imported', v_imported,
    'failed', v_failed,
    'verification_status', 'unverified',
    'results', v_results
  );
end;
$function$;

revoke all on function public.register_underground_assets_batch_server(uuid,jsonb,uuid) from public, anon, authenticated;
grant execute on function public.register_underground_assets_batch_server(uuid,jsonb,uuid) to service_role;
