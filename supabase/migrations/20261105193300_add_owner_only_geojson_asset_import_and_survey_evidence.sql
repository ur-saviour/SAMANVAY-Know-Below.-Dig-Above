-- Server-side utility asset ingestion and owner-scoped GeoJSON API.
grant usage on schema gis to authenticated;
grant select, insert, update on gis.underground_assets to authenticated;
grant select, insert on gis.asset_survey_evidence to authenticated;

create or replace function public.register_underground_asset(
  p_asset_code text,p_asset_name text,p_asset_type text,p_geometry jsonb,p_source_type text,
  p_source_reference text default null,p_depth_m numeric default null,
  p_horizontal_accuracy_m numeric default null,p_vertical_accuracy_m numeric default null,
  p_material text default null,p_diameter_mm numeric default null,
  p_surveyed_at timestamptz default null,p_surveyed_by_org text default null,
  p_verification_notes text default null
)
returns uuid language plpgsql security invoker set search_path=''
as $function$
declare
  v_department_id uuid;
  v_geometry extensions.geometry;
  v_asset_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select p.department_id into v_department_id
  from public.profiles p where p.id=(select auth.uid()) and p.role='department';
  if v_department_id is null then raise exception 'Only an owning department account can register utility assets'; end if;
  if p_asset_code is null or length(btrim(p_asset_code))<2 or length(p_asset_code)>100 then
    raise exception 'Asset code must contain 2 to 100 characters';
  end if;
  if p_asset_name is null or length(btrim(p_asset_name))<2 or length(p_asset_name)>200 then
    raise exception 'Asset name must contain 2 to 200 characters';
  end if;
  if p_asset_type not in ('water','sewer','stormwater','electricity','telecom','gas','borewell','drain','other','unknown') then
    raise exception 'Unsupported asset type';
  end if;
  if p_source_type not in ('utility_owner','field_survey','as_built_drawing','public_dataset','estimated','other') then
    raise exception 'Unsupported source type';
  end if;
  if p_geometry is null or jsonb_typeof(p_geometry)<>'object' then
    raise exception 'A GeoJSON geometry object is required';
  end if;
  if p_depth_m is not null and (p_depth_m<0 or p_depth_m>100) then raise exception 'Depth must be between 0 and 100 metres'; end if;
  if p_horizontal_accuracy_m is not null and (p_horizontal_accuracy_m<0 or p_horizontal_accuracy_m>1000) then raise exception 'Horizontal accuracy must be between 0 and 1000 metres'; end if;
  if p_vertical_accuracy_m is not null and (p_vertical_accuracy_m<0 or p_vertical_accuracy_m>1000) then raise exception 'Vertical accuracy must be between 0 and 1000 metres'; end if;
  if p_diameter_mm is not null and (p_diameter_mm<=0 or p_diameter_mm>10000) then raise exception 'Diameter must be between 0 and 10000 millimetres'; end if;

  v_geometry := extensions.st_setsrid(extensions.st_geomfromgeojson(p_geometry::text),4326);
  if v_geometry is null or extensions.st_isempty(v_geometry) then raise exception 'GeoJSON geometry is empty'; end if;
  if extensions.st_geometrytype(v_geometry) not in ('ST_Point','ST_MultiPoint','ST_LineString','ST_MultiLineString') then
    raise exception 'Only Point, MultiPoint, LineString and MultiLineString geometry is accepted';
  end if;
  if not extensions.st_isvalid(v_geometry) then raise exception 'GeoJSON geometry is invalid'; end if;
  if extensions.st_xmin(v_geometry)<-180 or extensions.st_xmax(v_geometry)>180
     or extensions.st_ymin(v_geometry)<-90 or extensions.st_ymax(v_geometry)>90 then
    raise exception 'GeoJSON coordinates must be longitude/latitude in EPSG:4326';
  end if;

  insert into gis.underground_assets(
    asset_code,asset_name,asset_type,owner_department_id,geom,depth_m,
    horizontal_accuracy_m,vertical_accuracy_m,material,diameter_mm,
    operational_status,source_type,source_reference,verification_status,
    surveyed_at,surveyed_by_org,verification_notes,created_by
  ) values (
    btrim(p_asset_code),btrim(p_asset_name),p_asset_type,v_department_id,v_geometry,p_depth_m,
    p_horizontal_accuracy_m,p_vertical_accuracy_m,p_material,p_diameter_mm,
    'unknown',p_source_type,nullif(btrim(coalesce(p_source_reference,'')),''),
    'unverified',p_surveyed_at,p_surveyed_by_org,p_verification_notes,(select auth.uid())
  ) returning id into v_asset_id;
  return v_asset_id;
end;
$function$;

revoke all on function public.register_underground_asset(
  text,text,text,jsonb,text,text,numeric,numeric,numeric,text,numeric,timestamptz,text,text
) from public,anon;
grant execute on function public.register_underground_asset(
  text,text,text,jsonb,text,text,numeric,numeric,numeric,text,numeric,timestamptz,text,text
) to authenticated;

create or replace function public.get_my_department_assets_geojson(
  p_min_lon double precision,p_min_lat double precision,
  p_max_lon double precision,p_max_lat double precision
)
returns jsonb language sql stable security invoker set search_path=''
as $function$
  select jsonb_build_object(
    'type','FeatureCollection',
    'features',coalesce(jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',extensions.st_asgeojson(a.geom)::jsonb,
      'properties',jsonb_build_object(
        'id',a.id,'asset_code',a.asset_code,'asset_name',a.asset_name,
        'asset_type',a.asset_type,'depth_m',a.depth_m,
        'horizontal_accuracy_m',a.horizontal_accuracy_m,
        'vertical_accuracy_m',a.vertical_accuracy_m,'material',a.material,
        'diameter_mm',a.diameter_mm,'operational_status',a.operational_status,
        'source_type',a.source_type,'verification_status',a.verification_status,
        'surveyed_at',a.surveyed_at,'updated_at',a.updated_at
      )
    )),'[]'::jsonb)
  )
  from gis.underground_assets a
  join public.profiles p on p.id=(select auth.uid())
  where p.role='department' and p.department_id=a.owner_department_id
    and p_min_lon<p_max_lon and p_min_lat<p_max_lat
    and p_min_lon>=-180 and p_max_lon<=180
    and p_min_lat>=-90 and p_max_lat<=90
    and extensions.st_intersects(a.geom,extensions.st_makeenvelope(p_min_lon,p_min_lat,p_max_lon,p_max_lat,4326));
$function$;
revoke all on function public.get_my_department_assets_geojson(double precision,double precision,double precision,double precision) from public,anon;
grant execute on function public.get_my_department_assets_geojson(double precision,double precision,double precision,double precision) to authenticated;

create or replace function public.mark_underground_asset_verification(
  p_asset_id uuid,p_verification_status text,p_verification_notes text default null
)
returns void language plpgsql security invoker set search_path=''
as $function$
declare v_source_type text; v_source_reference text;
begin
  if p_verification_status not in ('field_surveyed','owner_confirmed','disputed','retired') then
    raise exception 'Unsupported verification status';
  end if;
  select a.source_type,a.source_reference into v_source_type,v_source_reference
  from gis.underground_assets a where a.id=p_asset_id;
  if not found then raise exception 'Asset not found or not visible to this department'; end if;
  if p_verification_status='owner_confirmed'
     and (v_source_type<>'utility_owner' or nullif(btrim(coalesce(v_source_reference,'')),'') is null) then
    raise exception 'Owner confirmation requires a utility-owner source and a non-empty source reference';
  end if;
  update gis.underground_assets
  set verification_status=p_verification_status,
      verification_notes=coalesce(p_verification_notes,verification_notes),
      verified_at=case when p_verification_status in ('field_surveyed','owner_confirmed') then now() else verified_at end,
      verified_by=case when p_verification_status in ('field_surveyed','owner_confirmed') then (select auth.uid()) else verified_by end,
      updated_at=now()
  where id=p_asset_id;
end;
$function$;
revoke all on function public.mark_underground_asset_verification(uuid,text,text) from public,anon;
grant execute on function public.mark_underground_asset_verification(uuid,text,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('samanvay-asset-survey-evidence','samanvay-asset-survey-evidence',false,20971520,
  array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=20971520,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'];

drop policy if exists "Asset survey evidence upload by owning department" on storage.objects;
create policy "Asset survey evidence upload by owning department" on storage.objects
  for insert to authenticated with check (
    bucket_id='samanvay-asset-survey-evidence'
    and (storage.foldername(name))[2]=(select auth.uid())::text
    and exists(select 1 from gis.underground_assets a where a.id::text=(storage.foldername(name))[1])
  );
drop policy if exists "Asset survey evidence read by owning department" on storage.objects;
create policy "Asset survey evidence read by owning department" on storage.objects
  for select to authenticated using (
    bucket_id='samanvay-asset-survey-evidence'
    and exists(
      select 1 from gis.asset_survey_evidence e
      join gis.underground_assets a on a.id=e.asset_id
      where e.evidence_storage_path=storage.objects.name
    )
  );
drop policy if exists "Asset survey evidence uploader cleanup" on storage.objects;
create policy "Asset survey evidence uploader cleanup" on storage.objects
  for delete to authenticated using (
    bucket_id='samanvay-asset-survey-evidence'
    and (storage.foldername(name))[2]=(select auth.uid())::text
    and exists(select 1 from gis.underground_assets a where a.id::text=(storage.foldername(name))[1])
  );
