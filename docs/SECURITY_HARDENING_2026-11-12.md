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


## Confirmed groundwater data-reduction incident — 9 November 2026

See the [full incident timeline and workflow run analysis](security/SAMANVAY_GROUNDWATER_DATA_RECOVERY_INCIDENT_2026-11-09.md).

This is a production data incident, not merely a workflow warning.

### Evidence from GitHub Actions

Four legacy workflows were pushed and automatically triggered on 9 November. Their logs show:

| Workflow | Run ID | Result | Production replacement reached? |
|---|---:|---|---|
| `recover-supabase-auth-readonly.yml` first run | 42703812857 | Failed during local archive extraction (`COPY 0`) | No |
| `recover-supabase-auth-readonly.yml` retry | 42703918033 | Failed parsing the SQL block before `TRUNCATE` | No |
| `recover-supabase-auth-readonly-v2.yml` | 42703969678 | Failed parsing the SQL block before `TRUNCATE` | No |
| `recover-supabase-auth-readonly-v3.yml` | 42704164596 | Failed on an invalid psql meta-command before `TRUNCATE` | No |
| `recover-supabase-auth-readonly-v4.yml` | 42704213811 | Replacement completed; final fresh-connection verification failed on SQL quoting | **Yes** |

Run 42704213811 logs explicitly record, in order:

1. The pre-change production table contained 1,911,126 rows, including 446,068 rows dated in 2025.
2. The encrypted archive was downloaded, decrypted and restored into a disposable PostgreSQL container. The local extraction validated 446,068 rows for 2025.
3. The production command executed `TRUNCATE TABLE public.groundwater_station_observations`.
4. The workflow committed the truncate, copied 446,068 2025 records back into the production table, validated the post-copy 2025-only row count and committed.
5. The fresh-connection verification step failed later because its SQL timestamp quoting was malformed. This failure happened after the destructive replacement had already committed.

### Current live state

The live database query confirms:

- Total rows: **446,068**.
- Rows outside calendar year 2025: **0**.
- Oldest observation: 1 January 2025.
- Newest observation: 31 December 2025, 18:00.
- Geocoded rows: 445,553.
- The 515 remaining rows have no complete latitude/longitude pair.

The matching post-workflow count and date range establish that the production table is currently the 2025-only result of the compaction.

### Recovery material

- The full encrypted database archive release `samanvay-db-archive-42686760504` was created before the replacement (9 November 2026, 19:53:50 UTC). Its backup workflow passed dump creation, checksum, local decrypt, PostgreSQL catalogue validation, publication and published-copy decrypt verification.
- The groundwater-specific encrypted archive release `samanvay-groundwater-raw-archive-42691241449` was published 9 November 2026, 20:17:17 UTC. The v4 workflow later downloaded and decrypted this archive successfully and verified the original 1,911,126-row table before extracting the 2025 subset.
- The groundwater archive asset is an 85,977,272-byte encrypted file. The database archive asset is an 87,594,360-byte encrypted file. The decryption passphrase is held by the repository's GitHub Actions secret; it is not exposed in the repository or this chat.

### Containment and next recovery action

- All four legacy destructive recovery workflows have been removed from the active branch.
- They are replaced by `.github/workflows/verify-groundwater-archive.yml`, a manual-only job that decrypts/restores the archived table only in a disposable local PostgreSQL container, verifies the full 1,911,126-row count and the 2025 subset, and has no Supabase database credentials or production write step.
- Production imports, backups, archive publication, restore drills and WAL maintenance workflows are manual-dispatch only.
- No database restoration was performed during this audit.
- The safe recovery design is to decrypt and inspect the pre-change archive in an isolated PostgreSQL instance, compare the 2025 records against production using both primary key `id` and the unique source key `(source_resource_id, source_record_id)`, and build a verified delta of missing historical rows. Only after the staged delta is validated should a separate approved, transaction-controlled additive insert be considered. Do not truncate or overwrite the current table.
- A production write is deliberately not included in this hardening pass. The recovery requires a separate explicit go-ahead after the staging report confirms exact row counts, key conflicts, null/coordinate distributions and preserved 2025-row equivalence.

### Audit limitation

The 9 November GitHub Actions logs provide direct evidence of the workflow and SQL statements. Current database counts confirm the resulting state. They do not establish whether other independent maintenance operations affected other tables; this incident record is scoped to `public.groundwater_station_observations`.
