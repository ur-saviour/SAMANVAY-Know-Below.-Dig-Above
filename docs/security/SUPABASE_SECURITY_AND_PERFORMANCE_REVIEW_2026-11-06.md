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
- All ten SECURITY DEFINER functions flagged by the advisor were reviewed for an `auth.uid()` check, role/ownership gate logic and an empty fixed `search_path`. The warnings remain visible because these functions are intentionally callable by authenticated users and enforce their own authorization checks. They require ongoing tests; do not blanket-revoke them because some support core workflows and RLS helpers.

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
- Keep reviewing the ten SECURITY DEFINER functions with adversarial authorization tests as roles and workflows evolve.
- The GIS asset registry currently contains zero records. This is an empty registry, not proof that underground utilities are absent.
- No government utility dataset has been represented as acquired or verified merely because a portal is publicly accessible.

## Release validation

- Flutter static analysis passed for the updated GIS import client.
- Browser portal build and packaging passed.
- The Android release build for the updated GIS import client was still running at the time of this review; check the associated GitHub Actions run before distributing that build.
