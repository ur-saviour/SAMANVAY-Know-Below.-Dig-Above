-- Return complete national directory totals without transferring every row
-- through PostgREST (whose configured row limit may truncate large directories).
-- SECURITY INVOKER preserves the caller's existing RLS visibility.
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
    count(*)::bigint as total_count,
    count(*) filter (
      where u.verification_status = 'authority_verified'
    )::bigint as verified_count
  from public.india_administrative_units u
  where coalesce(u.is_active, true)
  group by u.unit_type
  order by u.unit_type;
$$;

revoke all on function public.get_india_administrative_unit_counts() from public, anon;
grant execute on function public.get_india_administrative_unit_counts() to authenticated;

comment on function public.get_india_administrative_unit_counts() is
  'National administrative directory totals by unit type, computed under caller RLS. Counts do not certify source accuracy or statutory status.';
