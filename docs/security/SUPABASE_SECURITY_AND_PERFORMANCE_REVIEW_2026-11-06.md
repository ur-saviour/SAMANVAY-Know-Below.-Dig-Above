# SAMANVAY Supabase security and performance review — 6 November 2026

## Verified controls

- The private `gis` schema has no `USAGE` grant for the mobile `authenticated` role.
- Direct `SELECT`, `INSERT` and `UPDATE` privileges on `gis.underground_assets` and `gis.asset_survey_evidence` are revoked from mobile users.
- Both GIS tables have RLS enabled and no policies. This is intentional default-deny protection; exact utility geometry is not exposed through the mobile Data API.
- The server-side asset registration functions are executable by `service_role` only. Database privilege checks confirmed `authenticated=false`, `anon=false`, `service_role=true`.
- The Edge Function `samanvay-asset-registry` is active with JWT verification enabled. It verifies the caller's access token, derives the department from the database profile, and does not accept a client-supplied role or department.
- The batch registration function rejects an actor without an assigned department before processing any asset.
- Imported records are always stored with `verification_status='unverified'` and `operational_status='unknown'`.
- The map's mobile utility layer returns only generalised 250 m coverage cells with a minimum aggregate count of three. It does not return exact routes.
- Twelve SECURITY DEFINER functions are currently reported by the Supabase security advisor as executable by authenticated users: admin_create_department, admin_set_service_domain_route, admin_update_profile_role, admin_user_directory, assign_request_department, change_request_status, get_my_department_verified_assets_geojson, get_underground_asset_overview, is_department_assigned_to_request, run_request_coordination_check, get_map_utility_conflict_advisories and submit_department_review. Function bodies were inspected for caller identity and role/department/request ownership checks; the GIS RPC specifically requires an authenticated profile with role department and a non-null department assignment. The checked RPC ACLs deny anon execution. The advisor warnings remain because these functions intentionally use elevated privileges and are callable by signed-in users. Treat this as a monitored risk, not a clean bill of health: add adversarial role/ownership tests and consider moving privileged implementations behind a non-exposed schema/API boundary. Do not blanket-revoke functions without tracing their callers, because some support core workflows.

## Performance remediation

The performance advisor identified eight foreign-key columns without covering indexes. The following indexes were added:

- `admin_audit_events(actor_id)`
- `admin_audit_events(target_user_id)`
- `case_ai_assessments(reviewed_by)`
- `case_attachments(uploaded_by)`
- `case_coordination_checks(checked_by)`
- `case_inspections(inspected_by)`
- `case_messages(sender_id)`
- `user_notifications(request_id)`

The follow-up advisor check returned no `unindexed_foreign_keys` finding.

## Remaining action

- Supabase Auth leaked-password protection is currently disabled. Enable it in the project's Auth security settings and verify the setting after saving.
- Keep reviewing the eleven SECURITY DEFINER functions with adversarial authorization tests as roles and workflows evolve. In particular, the department-only exact-asset RPC is a deliberate privilege boundary and must remain restricted to assigned department profiles.

- The new `get_map_utility_conflict_advisories(uuid[])` RPC is callable only by authenticated staff profiles (department, coordinator, admin), checks every request ID against caller permissions (department profile assignment or explicit request-review assignment), screens verified assets across departments on the server, and returns only asset type, owner department, distance, depth and horizontal-accuracy metadata. It does not return asset IDs/codes/names, coordinates or geometry. Its `SECURITY DEFINER` advisor warning is expected and must remain monitored; the function pins an empty search path, qualifies object names, explicitly checks `auth.uid()` and profile role, and revokes execution from `PUBLIC` and `anon`.
- The existing `run_request_coordination_check` now considers verified assets only and reports `unavailable` when no verified assets are registered, instead of treating an empty registry as a clean result.
- A transaction-based QA test used temporary synthetic verified and unverified records, confirmed exactly one verified proximity match, confirmed no asset identity/geometry was returned, confirmed requester-role denial, and rolled back all test data.

- The GIS asset registry currently contains zero records. This is an empty registry, not proof that underground utilities are absent.
- No government utility dataset has been represented as acquired or verified merely because a portal is publicly accessible.

## Release validation

- Flutter static analysis passed for the updated GIS import client.
- Browser portal build and packaging passed.
- The universal Alpha 0.3 APK build completed, but inspection showed it uses a temporary Android Debug certificate. It is suitable for development installation, not stable production signing.
- A follow-up workflow now builds ABI-specific APKs and makes package, signature and alignment checks mandatory. Run 42181324894 is the active validation run at the time of this update; do not distribute the new ABI-specific artifacts until that run succeeds.

## Follow-up advisor snapshot — 6 November 2026, 07:29 UTC

- Security advisor: two GIS tables (gis.underground_assets, gis.asset_survey_evidence) have RLS enabled with no policies. This remains intentional default-deny because the gis schema has no USAGE grant to mobile roles and the tables have no direct mobile grants. Do not add policies or grants independently; preserve the RPC/Edge Function access boundary.
- Security advisor: eleven authenticated-executable SECURITY DEFINER functions listed above. These warnings are not dismissed; the body-level authorization gates and function ACLs are part of the control and require regression testing.
- Security advisor: leaked-password protection remains disabled. A project owner must enable it in Supabase Auth security settings and verify it after saving.
- Performance advisor: 34 indexes were reported unused in this early, low-volume environment. Do not drop them based only on this snapshot; re-evaluate after representative workload and query-plan measurements.
- Performance advisor: the prior eight unindexed foreign-key findings remain remediated; verify again after future schema changes.