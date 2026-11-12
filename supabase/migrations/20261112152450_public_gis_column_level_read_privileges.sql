-- Keep anonymous GIS browsing limited to explicitly public reference columns.
-- Row-level policies from 20261112152243 remain in force; staff and operational
-- records are not made public by this migration.

revoke all privileges on table
  public.india_state_uts,
  public.india_data_coverage,
  public.india_administrative_units
from anon;

grant select (id, name, jurisdiction_type)
  on table public.india_state_uts to anon;

grant select (
  id,
  state_ut_id,
  data_domain,
  responsible_authority,
  official_portal_url,
  national_source_url,
  coverage_status,
  data_granularity,
  operational_use_allowed,
  last_checked_at,
  notes,
  telemetry_resource_count,
  telemetry_records_imported,
  telemetry_source_records,
  telemetry_status
)
  on table public.india_data_coverage to anon;

grant select (
  id,
  state_ut_id,
  parent_unit_id,
  unit_type,
  lgd_code,
  name,
  source_system,
  source_updated_at,
  verification_status,
  is_active,
  source_vintage
)
  on table public.india_administrative_units to anon;
