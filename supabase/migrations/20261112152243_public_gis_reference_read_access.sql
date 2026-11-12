-- Public GIS can read reference-only national jurisdiction metadata.
-- Operational work, verified underground assets and staff records remain protected.
grant select on table
  public.india_state_uts,
  public.india_data_coverage,
  public.india_administrative_units
to anon;

drop policy if exists "Public read India state and UT reference" on public.india_state_uts;
create policy "Public read India state and UT reference"
  on public.india_state_uts
  for select
  to anon
  using (true);

drop policy if exists "Public read national infrastructure coverage metadata" on public.india_data_coverage;
create policy "Public read national infrastructure coverage metadata"
  on public.india_data_coverage
  for select
  to anon
  using (true);

drop policy if exists "Public read active India administrative reference directory" on public.india_administrative_units;
create policy "Public read active India administrative reference directory"
  on public.india_administrative_units
  for select
  to anon
  using (
    coalesce(is_active, true)
    and verification_status in ('imported_unverified', 'authority_verified')
  );

-- SECURITY INVOKER preserves the same RLS boundary for aggregate counts.
grant execute on function public.get_india_administrative_unit_counts() to anon;
