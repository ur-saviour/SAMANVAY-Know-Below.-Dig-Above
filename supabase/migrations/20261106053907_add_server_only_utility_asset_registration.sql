create or replace function public.register_underground_asset_server(
  p_actor_id uuid,
  p_asset_code text,
  p_asset_name text,
  p_asset_type text,
  p_geometry jsonb,
  p_source_type text,
  p_source_reference text default null,
  p_depth_m numeric default null,
  p_horizontal_accuracy_m numeric default null,
  p_vertical_accuracy_m numeric default null,
  p_material text default null,
  p_diameter_mm numeric default null,
  p_surveyed_at timestamptz default null,
  p_surveyed_by_org text default null,
  p_verification_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_department_id uuid;
  v_geometry extensions.geometry;
  v_asset_id uuid;
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
  if p_asset_code is null or length(btrim(p_asset_code)) < 2 or length(p_asset_code) > 100 then
    raise exception 'Asset code must contain 2 to 100 characters';
  end if;
  if p_asset_name is null or length(btrim(p_asset_name)) < 2 or length(p_asset_name) > 200 then
    raise exception 'Asset name must contain 2 to 200 characters';
  end if;
  if p_asset_type not in ('water','sewer','stormwater','electricity','telecom','gas','borewell','drain','other','unknown') then
    raise exception 'Unsupported asset type';
  end if;
  if p_source_type not in ('utility_owner','field_survey','as_built_drawing','public_dataset','estimated','other') then
    raise exception 'Unsupported source type';
  end if;
  if p_geometry is null or jsonb_typeof(p_geometry) <> 'object' then
    raise exception 'A GeoJSON geometry object is required';
  end if;
  if p_depth_m is not null and (p_depth_m < 0 or p_depth_m > 100) then
    raise exception 'Depth must be between 0 and 100 metres';
  end if;
  if p_horizontal_accuracy_m is not null and (p_horizontal_accuracy_m < 0 or p_horizontal_accuracy_m > 1000) then
    raise exception 'Horizontal accuracy must be between 0 and 1000 metres';
  end if;
  if p_vertical_accuracy_m is not null and (p_vertical_accuracy_m < 0 or p_vertical_accuracy_m > 1000) then
    raise exception 'Vertical accuracy must be between 0 and 1000 metres';
  end if;
  if p_diameter_mm is not null and (p_diameter_mm <= 0 or p_diameter_mm > 10000) then
    raise exception 'Diameter must be between 0 and 10000 millimetres';
  end if;

  v_geometry := extensions.st_setsrid(extensions.st_geomfromgeojson(p_geometry::text), 4326);
  if v_geometry is null or extensions.st_isempty(v_geometry) then
    raise exception 'GeoJSON geometry is empty';
  end if;
  if extensions.st_geometrytype(v_geometry) not in ('ST_Point','ST_MultiPoint','ST_LineString','ST_MultiLineString') then
    raise exception 'Only Point, MultiPoint, LineString and MultiLineString geometry is accepted';
  end if;
  if not extensions.st_isvalid(v_geometry) then
    raise exception 'GeoJSON geometry is invalid';
  end if;
  if extensions.st_xmin(v_geometry) < -180 or extensions.st_xmax(v_geometry) > 180
     or extensions.st_ymin(v_geometry) < -90 or extensions.st_ymax(v_geometry) > 90 then
    raise exception 'GeoJSON coordinates must be longitude/latitude in EPSG:4326';
  end if;

  insert into gis.underground_assets (
    asset_code, asset_name, asset_type, owner_department_id, geom,
    depth_m, horizontal_accuracy_m, vertical_accuracy_m, material, diameter_mm,
    operational_status, source_type, source_reference, verification_status,
    surveyed_at, surveyed_by_org, verification_notes, created_by
  ) values (
    btrim(p_asset_code), btrim(p_asset_name), p_asset_type, v_department_id, v_geometry,
    p_depth_m, p_horizontal_accuracy_m, p_vertical_accuracy_m, p_material, p_diameter_mm,
    'unknown', p_source_type, nullif(btrim(coalesce(p_source_reference, '')), ''),
    'unverified', p_surveyed_at, p_surveyed_by_org, p_verification_notes, p_actor_id
  )
  returning id into v_asset_id;
  return v_asset_id;
end;
$function$;

revoke all on function public.register_underground_asset_server(
  uuid,text,text,text,jsonb,text,text,numeric,numeric,numeric,text,numeric,timestamptz,text,text
) from public, anon, authenticated;
grant execute on function public.register_underground_asset_server(
  uuid,text,text,text,jsonb,text,text,numeric,numeric,numeric,text,numeric,timestamptz,text,text
) to service_role;
