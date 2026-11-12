-- Make the client-side deny boundary explicit in RLS as defense in depth.
-- Exact asset geometry and survey evidence are accessed only by narrowly scoped
-- server-checked functions/Edge Functions; authenticated clients receive no table grants.

drop policy if exists deny_client_reads_and_writes_underground_assets
  on gis.underground_assets;
create policy deny_client_reads_and_writes_underground_assets
  on gis.underground_assets
  for all to anon, authenticated
  using (false)
  with check (false);

drop policy if exists deny_client_reads_and_writes_asset_survey_evidence
  on gis.asset_survey_evidence;
create policy deny_client_reads_and_writes_asset_survey_evidence
  on gis.asset_survey_evidence
  for all to anon, authenticated
  using (false)
  with check (false);

comment on policy deny_client_reads_and_writes_underground_assets
  on gis.underground_assets is
  'Client direct access is denied; owner-scoped/server-mediated paths enforce their own identity and role checks.';
comment on policy deny_client_reads_and_writes_asset_survey_evidence
  on gis.asset_survey_evidence is
  'Client direct access is denied; evidence access is mediated by the private storage helpers and secure Edge Functions.';
