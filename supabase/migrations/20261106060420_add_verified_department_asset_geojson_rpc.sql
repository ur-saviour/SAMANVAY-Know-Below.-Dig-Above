create or replace function public.get_my_department_verified_assets_geojson(
  p_min_lon double precision,
  p_min_lat double precision,
  p_max_lon double precision,
  p_max_lat double precision
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_department_id uuid;
  v_features jsonb;
  v_withheld integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  select p.department_id into v_department_id
  from public.profiles p
  where p.id = (select auth.uid())
    and p.role = 'department'
    and p.department_id is not null;

  if v_department_id is null then
    raise exception 'An assigned department account is required';
  end if;

  if p_min_lon is null or p_min_lat is null or p_max_lon is null or p_max_lat is null
     or p_min_lon >= p_max_lon or p_min_lat >= p_max_lat
     or p_min_lon < -180 or p_max_lon > 180
     or p_min_lat < -90 or p_max_lat > 90 then
    raise exception 'Invalid WGS84 viewport bounds';
  end if;

  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'type','Feature',
          'id',a.id,
          'geometry',extensions.st_asgeojson(a.geom)::jsonb,
          'properties',jsonb_build_object(
            'id',a.id,
            'asset_code',a.asset_code,
            'asset_name',a.asset_name,
            'asset_type',a.asset_type,
            'depth_m',a.depth_m,
            'horizontal_accuracy_m',a.horizontal_accuracy_m,
            'vertical_accuracy_m',a.vertical_accuracy_m,
            'material',a.material,
            'diameter_mm',a.diameter_mm,
            'operational_status',a.operational_status,
            'source_type',a.source_type,
            'verification_status',a.verification_status,
            'surveyed_at',a.surveyed_at,
            'updated_at',a.updated_at
          )
        ) order by a.asset_code
      ) filter (where a.verification_status = 'verified'),
      '[]'::jsonb
    ),
    count(*) filter (where a.verification_status is distinct from 'verified')::integer
  into v_features, v_withheld
  from gis.underground_assets a
  where a.owner_department_id = v_department_id
    and extensions.st_intersects(
      a.geom,
      extensions.st_makeenvelope(p_min_lon,p_min_lat,p_max_lon,p_max_lat,4326)
    );

  return jsonb_build_object(
    'type','FeatureCollection',
    'features',v_features,
    'metadata',jsonb_build_object(
      'withheld_unverified_count',coalesce(v_withheld,0),
      'geometry_scope','verified assets owned by the authenticated department'
    )
  );
end;
$function$;

revoke all on function public.get_my_department_verified_assets_geojson(double precision,double precision,double precision,double precision)
from public, anon, authenticated;
grant execute on function public.get_my_department_verified_assets_geojson(double precision,double precision,double precision,double precision)
to authenticated;
