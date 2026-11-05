-- Exact utility geometry is restricted to the utility-owning department.
-- Coordinators/admins use a separate aggregate-only RPC; no exact routes or IDs are returned.

drop policy if exists "GIS assets visible to authorised infrastructure roles" on gis.underground_assets;
create policy "Only owning department can read exact utility geometry"
  on gis.underground_assets for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role='department'
      and p.department_id=underground_assets.owner_department_id
  ));

drop policy if exists "Departments may register their own asset records" on gis.underground_assets;
create policy "Only owning department can register its asset records"
  on gis.underground_assets for insert to authenticated
  with check (
    created_by=(select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id=(select auth.uid()) and p.role='department'
        and p.department_id=underground_assets.owner_department_id
    )
  );

drop policy if exists "Only platform administrators and coordinators may update GIS assets" on gis.underground_assets;
create policy "Only owning department can update exact utility records"
  on gis.underground_assets for update to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role='department'
      and p.department_id=underground_assets.owner_department_id
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role='department'
      and p.department_id=underground_assets.owner_department_id
  ));

drop policy if exists "Survey evidence visible with its authorised asset" on gis.asset_survey_evidence;
create policy "Survey evidence visible only to owning department"
  on gis.asset_survey_evidence for select to authenticated
  using (exists (
    select 1 from gis.underground_assets a
    join public.profiles p on p.id=(select auth.uid())
    where a.id=asset_survey_evidence.asset_id
      and p.role='department' and p.department_id=a.owner_department_id
  ));

drop policy if exists "Departments may append evidence to their own assets" on gis.asset_survey_evidence;
create policy "Only owning department can append survey evidence"
  on gis.asset_survey_evidence for insert to authenticated
  with check (
    recorded_by=(select auth.uid())
    and exists (
      select 1 from gis.underground_assets a
      join public.profiles p on p.id=(select auth.uid())
      where a.id=asset_survey_evidence.asset_id
        and p.role='department' and p.department_id=a.owner_department_id
    )
  );

-- Cross-department coordination gets generalized 250 m coverage only.
-- The function never returns exact utility geometry, IDs, type, depth or owner identifiers.
-- SECURITY DEFINER is intentional so privileged aggregate reads continue after exact table
-- geometry is restricted by RLS. The function independently checks auth.uid() and profile role.
create or replace function public.get_underground_asset_overview(
  p_min_lon double precision,p_min_lat double precision,
  p_max_lon double precision,p_max_lat double precision
)
returns jsonb language sql stable security definer set search_path=''
as $function$
  with authorised_role as (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator','department')
  ),
  projected as (
    select extensions.st_transform(a.geom,3857) as geom_3857,a.updated_at
    from gis.underground_assets a
    where exists(select 1 from authorised_role)
      and p_min_lon<p_max_lon and p_min_lat<p_max_lat
      and p_min_lon>=-180 and p_max_lon<=180
      and p_min_lat>=-90 and p_max_lat<=90
      and extensions.st_intersects(
        a.geom,extensions.st_makeenvelope(p_min_lon,p_min_lat,p_max_lon,p_max_lat,4326)
      )
  ),
  cells as (
    select floor(extensions.st_x(extensions.st_centroid(geom_3857))/250)::bigint as gx,
      floor(extensions.st_y(extensions.st_centroid(geom_3857))/250)::bigint as gy,
      count(*)::integer as asset_count,max(updated_at) as last_updated
    from projected group by 1,2 having count(*)>=3
  )
  select jsonb_build_object(
    'type','FeatureCollection',
    'features',coalesce(jsonb_agg(jsonb_build_object(
      'type','Feature',
      'geometry',extensions.st_asgeojson(extensions.st_transform(
        extensions.st_makeenvelope(gx*250,gy*250,(gx+1)*250,(gy+1)*250,3857),4326
      ))::jsonb,
      'properties',jsonb_build_object('asset_count',asset_count,'last_updated',last_updated)
    )),'[]'::jsonb)
  ) from cells;
$function$;

revoke all on function public.get_underground_asset_overview(
  double precision,double precision,double precision,double precision
) from public,anon;
grant execute on function public.get_underground_asset_overview(
  double precision,double precision,double precision,double precision
) to authenticated;
