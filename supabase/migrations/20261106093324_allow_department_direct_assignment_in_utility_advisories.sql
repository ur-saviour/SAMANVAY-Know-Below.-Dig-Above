create or replace function public.get_map_utility_conflict_advisories(
  p_request_ids uuid[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_role text;
  v_department_id uuid;
  v_requested_count integer;
  v_authorized_count integer;
  v_has_verified_assets boolean;
  v_results jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select p.role, p.department_id
    into v_role, v_department_id
  from public.profiles p
  where p.id = v_user_id;

  if v_role is null or v_role not in ('department', 'coordinator', 'admin') then
    raise exception 'An authorised staff account is required';
  end if;

  if v_role = 'department' and v_department_id is null then
    raise exception 'An assigned department account is required';
  end if;

  if p_request_ids is null or cardinality(p_request_ids) = 0 then
    return jsonb_build_object(
      'results', '[]'::jsonb,
      'verified_assets_available', exists (
        select 1 from gis.underground_assets a
        where a.verification_status = 'verified'
      ),
      'geometry_disclosed', false
    );
  end if;

  if cardinality(p_request_ids) > 500 then
    raise exception 'A maximum of 500 request IDs can be screened per call';
  end if;

  if array_position(p_request_ids, null) is not null then
    raise exception 'Request ID list cannot contain null values';
  end if;

  select count(distinct x)::integer into v_requested_count
  from unnest(p_request_ids) as ids(x);

  select count(*)::integer into v_authorized_count
  from public.excavation_requests r
  where r.id = any(p_request_ids)
    and (
      v_role in ('admin', 'coordinator')
      or (
        v_role = 'department'
        and (
          r.department_id = v_department_id
          or public.is_department_assigned_to_request(r.id)
        )
      )
    );

  if v_authorized_count <> v_requested_count then
    raise exception 'One or more requests are unavailable or not assigned to this account';
  end if;

  select exists (
    select 1 from gis.underground_assets a
    where a.verification_status = 'verified'
  ) into v_has_verified_assets;

  with requested as (
    select r.id, r.request_number, r.work_location, r.work_radius_m
    from public.excavation_requests r
    where r.id = any(p_request_ids)
  ),
  screened as (
    select
      r.id,
      r.request_number,
      r.work_radius_m,
      case
        when r.work_location is null then 'missing_work_location'
        when r.work_radius_m is null then 'missing_work_radius'
        when not v_has_verified_assets then 'unavailable_no_verified_assets'
        when c.conflict_count > 0 then 'potential_conflict'
        else 'screened_no_proximity_match'
      end as screening_status,
      c.conflict_count,
      c.conflicts
    from requested r
    cross join lateral (
      select
        count(*)::integer as conflict_count,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'asset_type', matches.asset_type,
              'owner_department', matches.owner_department,
              'distance_m', matches.distance_m,
              'depth_m', matches.depth_m,
              'horizontal_accuracy_m', matches.horizontal_accuracy_m
            )
            order by matches.distance_m
          ),
          '[]'::jsonb
        ) as conflicts
      from (
        select
          a.asset_type,
          d.name as owner_department,
          round(
            extensions.st_distance(
              a.geom::extensions.geography,
              r.work_location::extensions.geography
            )::numeric,
            1
          ) as distance_m,
          a.depth_m,
          a.horizontal_accuracy_m
        from gis.underground_assets a
        join public.departments d on d.id = a.owner_department_id
        where a.verification_status = 'verified'
          and r.work_location is not null
          and r.work_radius_m is not null
          and extensions.st_dwithin(
            a.geom::extensions.geography,
            r.work_location::extensions.geography,
            (
              r.work_radius_m
              + least(greatest(coalesce(a.horizontal_accuracy_m, 0), 0), 500)
              + 3
            )::double precision
          )
      ) matches
    ) c
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'request_id', s.id,
        'request_number', s.request_number,
        'work_radius_m', s.work_radius_m,
        'screening_status', s.screening_status,
        'candidate_count', s.conflict_count,
        'conflicts', s.conflicts
      )
      order by s.request_number
    ),
    '[]'::jsonb
  )
  into v_results
  from screened s;

  return jsonb_build_object(
    'results', v_results,
    'verified_assets_available', v_has_verified_assets,
    'geometry_disclosed', false,
    'disclaimer', 'Advisory screening only. No match is not utility clearance or proof of site safety.'
  );
end;
$function$;
