-- Do not expose detailed utility geometry or survey evidence through the mobile Data API.
-- Authoritative ingestion and geometry processing remain server-side; client RPCs expose only
-- generalized 250 m coverage and a generic case-level proximity/clearance warning.

drop policy if exists "Only owning department can read exact utility geometry" on gis.underground_assets;
drop policy if exists "Only owning department can register its asset records" on gis.underground_assets;
drop policy if exists "Only owning department can update exact utility records" on gis.underground_assets;
drop policy if exists "Survey evidence visible only to owning department" on gis.asset_survey_evidence;
drop policy if exists "Only owning department can append survey evidence" on gis.asset_survey_evidence;

revoke all on schema gis from authenticated;
revoke all on gis.underground_assets from authenticated;
revoke all on gis.asset_survey_evidence from authenticated;

revoke all on function public.register_underground_asset(
  text,text,text,jsonb,text,text,numeric,numeric,numeric,text,numeric,timestamptz,text,text
) from public,anon,authenticated;
revoke all on function public.get_my_department_assets_geojson(
  double precision,double precision,double precision,double precision
) from public,anon,authenticated;
revoke all on function public.mark_underground_asset_verification(uuid,text,text) from public,anon,authenticated;
revoke all on function public.record_asset_survey_evidence(uuid,text,date,numeric,numeric,text,text,text) from public,anon,authenticated;

drop policy if exists "Asset survey evidence upload by owning department" on storage.objects;
drop policy if exists "Asset survey evidence read by owning department" on storage.objects;
drop policy if exists "Asset survey evidence uploader cleanup" on storage.objects;
