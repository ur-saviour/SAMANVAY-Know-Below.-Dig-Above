-- Restore exact utility geometry to owner-scoped/server-mediated access.
-- Coordinators and administrators must use the metadata-only review queue rather
-- than querying exact geometry or evidence directly through the client Data API.

drop policy if exists admins_coordinators_read_underground_assets
  on gis.underground_assets;
drop policy if exists admins_coordinators_read_asset_survey_evidence
  on gis.asset_survey_evidence;

revoke all privileges on table
  gis.underground_assets,
  gis.asset_survey_evidence
from public, anon, authenticated;

alter view public.utility_asset_verification_queue
  set (security_invoker = false, security_barrier = true);

revoke all privileges on table public.utility_asset_verification_queue
  from public, anon, authenticated;
grant select on table public.utility_asset_verification_queue
  to authenticated;

comment on table gis.underground_assets is
  'Restricted exact utility asset registry. No direct anon/authenticated Data API access; use narrowly scoped server-checked RPCs.';
comment on table gis.asset_survey_evidence is
  'Restricted utility survey evidence. No direct anon/authenticated Data API access.';
comment on view public.utility_asset_verification_queue is
  'Metadata-only review projection. Readable only to authenticated admin/coordinator profiles; exact utility geometry is not returned.';
