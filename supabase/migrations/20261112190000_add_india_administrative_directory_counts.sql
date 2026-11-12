-- Count distinct LGD codes rather than duplicate historical/reference rows.
create or replace function public.get_india_administrative_unit_counts()
returns table (
  unit_type text,
  total_count bigint,
  verified_count bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    u.unit_type::text,
    count(distinct u.lgd_code)::bigint as total_count,
    count(distinct u.lgd_code) filter (
      where u.verification_status = 'authority_verified'
    )::bigint as verified_count
  from public.india_administrative_units u
  where coalesce(u.is_active, true)
    and u.lgd_code is not null
  group by u.unit_type
  order by u.unit_type;
$$;

revoke all on function public.get_india_administrative_unit_counts() from public, anon;
grant execute on function public.get_india_administrative_unit_counts() to authenticated;

comment on function public.get_india_administrative_unit_counts() is
  'Counts distinct active LGD-coded administrative units by type under caller RLS. Counts do not certify statutory boundary geometry.';
