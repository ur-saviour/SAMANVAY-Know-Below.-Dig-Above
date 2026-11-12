-- Harden the official utility verification queue without granting client write access.
-- The view is intentionally available to authenticated admin/coordinator accounts only.
-- Its underlying records remain protected by row-level security when queried through the view.

alter view public.utility_asset_verification_queue
  set (security_invoker = true);

grant select on public.utility_geometry_import_runs to authenticated;
grant select on gis.underground_assets, gis.asset_survey_evidence to authenticated;

drop policy if exists admins_coordinators_read_underground_assets
  on gis.underground_assets;
create policy admins_coordinators_read_underground_assets
  on gis.underground_assets
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('admin', 'coordinator')
    )
  );

drop policy if exists admins_coordinators_read_asset_survey_evidence
  on gis.asset_survey_evidence;
create policy admins_coordinators_read_asset_survey_evidence
  on gis.asset_survey_evidence
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('admin', 'coordinator')
    )
  );

drop policy if exists admins_coordinators_read_utility_geometry_import_runs
  on public.utility_geometry_import_runs;
create policy admins_coordinators_read_utility_geometry_import_runs
  on public.utility_geometry_import_runs
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role in ('admin', 'coordinator')
    )
  );

drop policy if exists server_only_ai_chat_usage_events
  on public.ai_chat_usage_events;
create policy server_only_ai_chat_usage_events
  on public.ai_chat_usage_events
  for all to anon, authenticated
  using (false) with check (false);

drop policy if exists server_only_groundwater_data_import_runs
  on public.groundwater_data_import_runs;
create policy server_only_groundwater_data_import_runs
  on public.groundwater_data_import_runs
  for all to anon, authenticated
  using (false) with check (false);

drop policy if exists server_only_utility_asset_review_events
  on public.utility_asset_review_events;
create policy server_only_utility_asset_review_events
  on public.utility_asset_review_events
  for all to anon, authenticated
  using (false) with check (false);
