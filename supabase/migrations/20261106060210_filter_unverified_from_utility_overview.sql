-- Never include unverified, estimated or unreviewed records in aggregate map coverage.
create or replace function public.get_underground_asset_overview(
  p_min_lon double precision,
  p_min_lat double precision,
  p_max_lon double precision,
  p_max_lat double precision
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  with authorised_role as (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin','coordinator','department')
  ),
  projected as (
    select
      extensions.st_transform(a.geom, 3857) as geom_3857,
      a.updated_at
    from gis.underground_assets a
    where exists (select 1 from authorised_role)
      and a.verification_status = 'verified'
      and p_min_lon < p_max_lon
      and p_min_lat < p_max_lat
      and p_min_lon >= -180 and p_max_lon <= 180
      and p_min_lat >= -90 and p_max_lat <= 90
      and extensions.st_intersects(
        a.geom,
        extensions.st_makeenvelope(p_min_lon,p_min_lat,p_max_lon,p_max_lat,4326)
      )
  ),
  cells as (
    select
      floor(extensions.st_x(extensions.st_centroid(geom_3857)) / 250)::bigint as gx,
      floor(extensions.st_y(extensions.st_centroid(geom_3857)) / 250)::bigint as gy,
      count(*)::integer as asset_count,
      max(updated_at) as last_updated
    from projected
    group by 1,2
    having count(*) >= 3
  )
  select jsonb_build_object(
    'type','FeatureCollection',
    'features',coalesce(
      jsonb_agg(
        jsonb_build_object(
          'type','Feature',
          'geometry',extensions.st_asgeojson(
            extensions.st_transform(
              extensions.st_makeenvelope(gx*250,gy*250,(gx+1)*250,(gy+1)*250,3857),
              4326
            )
          )::jsonb,
          'properties',jsonb_build_object(
            'asset_count',asset_count,
            'last_updated',last_updated
          )
        )
      ),
      '[]'::jsonb
    )
  )
  from cells;
$function$;
