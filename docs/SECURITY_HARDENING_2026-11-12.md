# SAMANVAY Security Hardening Record

**Audit date:** 12 November 2026  
**Repository branch:** `feature/alpha-03-integrated-platform`  
**Supabase project:** `zhtotivedvkmclerdnlf`

## Applied controls

### Exact utility geometry and survey evidence

- Revoked direct `SELECT` privileges for `anon` and `authenticated` on `gis.underground_assets` and `gis.asset_survey_evidence`.
- Removed the broad administrator/coordinator RLS read policies that had reintroduced direct table access.
- Added explicit deny-all RLS policies for client roles as defense in depth.
- Kept owner-department geometry access behind existing role- and department-checked server functions. The verified-asset RPC returns only verified assets owned by the caller's assigned department.
- Kept the public/operational map overview generalized; it returns aggregated 250 m cells only where at least three records contribute.

### Review queue

- Replaced the SECURITY DEFINER public view with a `security_invoker` view.
- The view is backed by `private.get_utility_asset_verification_queue()`, which checks the current `auth.uid()` against the live `profiles.role` value and permits only `admin` or `coordinator`.
- The queue projection contains review metadata and evidence references, not utility geometry.
- Verified an authenticated admin session can query the view and a department-role session is rejected by the private function's role guard.

### Asset review Edge Function

- Repaired bearer-token parsing in `samanvay-asset-review`; the previous deployed expression expected a literal backslash before `s` and rejected ordinary Bearer headers.
- Kept gateway JWT verification enabled.
- The function validates the JWT with Supabase Auth, looks up the current database role rather than trusting client metadata, and accepts only `admin` or `coordinator`.
- Aligned allowed decisions with the database RPC: `accept_evidence` and `reject`.
- Added request-size and payload-shape checks, bounded field validation, timeouts, and generic failure responses.
- Live deployment verified as active, version 3, with JWT verification enabled.

### Demo profile switching

- Audited the signed-in profile-page switcher and the staff preview implementation.
- Switching profiles opens `_StaffDemoPreview` with `PUBLIC-*` demo identifiers.
- The preview uses local in-memory sample cases and session-only actions; it contains no Supabase client calls, RPC invocations, or backend writes.
- The profile UI labels these workspaces as demo mode. Actual account-role changes use `admin_update_profile_role`, whose database function checks the current authenticated profile is an administrator and records an audit event.

## Database verification

The following checks were run after the migrations:

- Anonymous and authenticated direct table privileges for both exact asset tables: **false**.
- Authenticated read privilege on the metadata review view: **true**.
- Anonymous execute privilege on the private queue function: **false**.
- Authenticated execute privilege on the private queue function: **true**.
- Review view options: `security_invoker=true` and `security_barrier=true`.
- Supabase Security Advisor no longer reports the earlier SECURITY DEFINER view finding or the RLS-enabled-with-no-policy findings.

## Remaining advisor findings

### Intentional SECURITY DEFINER RPCs

The advisor still reports 16 authenticated-callable SECURITY DEFINER functions. These are privileged database operations, not blanket grants: the inspected functions pin `search_path`, resolve the caller through `auth.uid()`, and check the required administrator, coordinator, department, or request-assignment condition before returning protected data or mutating records. Do not revoke these wholesale; doing so would break core application workflows. Continue reviewing them when their authorization logic changes.

### Leaked-password protection

Supabase reports leaked-password protection is disabled. The connected organization is on the **Free** plan; Supabase documents this feature as available on Pro and above. This is a hosted Auth plan limitation, not something that can be safely fixed with an application-side workaround. Revisit it if the project plan changes.

Official reference: https://supabase.com/docs/guides/auth/password-security

## Migration files

- `20261112180516_restore_owner_scoped_utility_geometry_boundary.sql`
- `20261112181618_secure_metadata_only_utility_review_queue.sql`
- `20261112181901_add_explicit_deny_policies_for_restricted_utility_tables.sql`

## Verification boundary

The database privilege checks, RLS/queue checks, advisor rerun, repository source checks, and Edge Function deployment metadata were verified. A live authenticated HTTP invocation of the Edge Function was not performed in this pass; test the reviewer flow with a dedicated admin/coordinator test account before treating the review UI as end-to-end validated.
