# SAMANVAY 2.0 — Runtime and Data Acceptance Matrix

**Status:** Test specification; execution pending  
**Target branch:** `feature/samanvay-2-phase-2-environment`  
**Safety boundary:** All database mutation cases below must run only against an isolated disposable database or an explicitly approved staging project. Production is read-only.

## Why this gate exists

Successful Android and Web CI builds prove that source code compiles and required bundled assets are present. They do not prove that authentication, row-level security (RLS), PostGIS queries, role permissions, or the municipal workflow behave correctly at runtime.

The repository currently has no approved isolated Supabase staging database. Therefore this matrix defines executable acceptance criteria but does not claim that database-backed tests have passed.

## Migration replay prerequisite discovered during repository inspection

The engineering branch contains **75 files under `supabase/migrations/`**, but the sequence is not a self-contained bootstrap for an empty database. The earliest migration already alters policies on `gis.underground_assets` and `gis.asset_survey_evidence`, and references existing application objects such as `public.excavation_requests`, `public.profiles` and `public.departments`. It also uses Supabase-managed schemas and facilities such as `storage` and `auth.uid()`.

The repository tree does not contain a checked-in `supabase/config.toml` or a foundational migration that creates the core application schema and GIS tables before this sequence. Therefore:

1. Do **not** run the 75 migrations against a blank vanilla Postgres/PostGIS container and interpret the expected missing-object failures as defects in each additive migration.
2. Do **not** invent a baseline schema from the current application UI or infer that production's live schema is reproducible from this repository.
3. First obtain an owner-approved, sanitised schema-only export (including required extensions, schemas, roles/grants, auth/storage prerequisites and relevant function definitions), or recover the original foundational SQL/migration history from its authoritative source.
4. Review that baseline for secrets, personal data and production-specific configuration. Keep all data rows out of the export unless synthetic fixtures are deliberately created.
5. Only then build a disposable local Supabase/PostGIS replay job and execute the 75 migrations in timestamp order. Record any intentional dependency on Supabase-managed services.

**Current blocker:** foundational schema provenance is not present in this repository snapshot. No migration replay has been attempted, and no database-backed test is claimed as passed.

## Environment rules

1. Never point destructive or synthetic tests at the production Supabase project.
2. Do not create a paid Supabase branch or project without explicit approval from the project/account owner.
3. Prefer a disposable local Supabase stack with Postgres/PostGIS for SQL and RPC tests. Record the exact CLI, Postgres, PostGIS and migration versions.
4. Use synthetic geometry and synthetic user identities only. Do not fabricate official utility locations or label reference layers as verified assets.
5. Use separate authenticated sessions for Citizen, Department Officer, Coordinator and Administrator. Never simulate authorization by changing a client-side role label.
6. Store test credentials only in CI secrets or local environment variables; never commit them.

## Acceptance matrix

| ID | Domain | Test | Expected result | Evidence |
|---|---|---|---|---|
| AUTH-01 | Authentication | Sign in with a valid confirmed test account | Supabase session established; profile loaded from server | Test log with account identifier redacted |
| AUTH-02 | Authentication | Sign in with invalid credentials | Generic failure; no session or profile leakage | Test assertion |
| AUTH-03 | Authentication | Expired/revoked session accesses protected data | Request rejected; client returns to signed-out state | API response and app log |
| ROLE-01 | Authorization | Citizen reads public case/transparency data | Only fields explicitly approved for public access are returned | RLS assertion |
| ROLE-02 | Authorization | Citizen attempts officer-only review mutation | Denied by database policy/RPC authorization | SQL/API assertion |
| ROLE-03 | Authorization | Officer reads assigned departmental work | Only own department's permitted assignments are visible | RLS assertion |
| ROLE-04 | Authorization | Officer attempts another department's restricted operation | Denied server-side | RLS assertion |
| ROLE-05 | Authorization | Coordinator performs coordinator-only decision | Allowed only for authorized coordinator identity | RPC assertion |
| ROLE-06 | Authorization | Non-admin attempts role escalation | Denied; no profile role mutation | RLS/RPC assertion |
| GIS-01 | GIS | Insert synthetic asset with valid SRID and required metadata | Accepted only through authorized ingestion path; initial status remains unverified | Migration/RPC test |
| GIS-02 | GIS | Insert malformed geometry, unsupported SRID or invalid accuracy | Rejected with deterministic validation error | SQL assertion |
| GIS-03 | GIS | Citizen requests exact utility geometry | Exact geometry is not disclosed | RLS/API assertion |
| GIS-04 | GIS | Spatial screening runs with one verified synthetic asset intersecting the test buffer | Candidate conflict is returned with source confidence/accuracy context | SQL fixture and expected result |
| GIS-05 | GIS | Spatial screening runs with no registered assets | Result explicitly indicates no registered verified asset found; it must not state that the ground is utility-free | RPC assertion |
| GIS-06 | GIS | Unverified or expired asset is encountered | Must not be represented as confirmed clearance evidence | RPC assertion |
| CASE-01 | Workflow | Citizen submits a valid excavation case | Case created in allowed initial state; audit event recorded | API/DB assertion |
| CASE-02 | Workflow | Unassigned officer attempts review | Denied | RPC assertion |
| CASE-03 | Workflow | Assigned officer records review | Review and actor/time audit recorded | API/DB assertion |
| CASE-04 | Workflow | Coordinator records a coordination decision | Decision is authorized and linked to the case | API/DB assertion |
| PERMIT-01 | Permit | Attempt permit issuance before mandatory clearances | Blocked | DB assertion |
| PERMIT-02 | Permit | Attempt permit issuance after required approvals | Allowed only if every configured statutory/business prerequisite is met | DB assertion |
| RESTORE-01 | Restoration | Close restoration without accepted inspection | Blocked | DB assertion |
| RESTORE-02 | Restoration | Close restoration with required accepted evidence | Allowed and deadline/audit fields retained | DB assertion |
| AUDIT-01 | Audit | Read audit history as authorized role | Events are append-only to ordinary clients and actor/time are preserved | RLS/trigger assertion |

## Required synthetic spatial fixtures

Use a local projected metric CRS suitable for the test area, or explicitly transform from WGS84 before applying metre-based buffers. Never apply metre distances directly to longitude/latitude degrees.

Create fixtures with:
- One verified synthetic line asset crossing a synthetic excavation corridor.
- One verified synthetic line asset outside the screening buffer.
- One unverified asset near the corridor.
- One asset with deliberately poor positional accuracy.
- One case with no asset rows in the registry.

The expected result must account for the asset's positional uncertainty. A proximity candidate is a review trigger, not an instruction to excavate or a guarantee that a route is clear.

## Execution record template

For each run, record:
- Commit SHA and branch.
- Database engine and PostGIS versions.
- Migration head and whether every migration replayed from an empty database.
- Test command and UTC execution time.
- Test count, pass count, fail count and skipped count.
- Redacted logs and SQLSTATE for expected denials.
- Confirmation that the database was disposable/local or approved staging.
- Confirmation that production was not modified.

## Exit criteria

- [ ] Migrations replay successfully from an empty local PostGIS database.
- [ ] AUTH and ROLE tests pass using separate real Supabase-authenticated sessions.
- [ ] GIS tests pass, including uncertainty and empty-registry semantics.
- [ ] Case, permit and restoration transition tests pass.
- [ ] RLS tests prove unauthorized writes are denied by the database, not merely hidden in the UI.
- [ ] No exact utility geometry is exposed to unauthorized clients.
- [ ] Physical Android acceptance is recorded separately from CI build success.
- [ ] Browser acceptance is recorded separately from CI build success.

**Current result:** Not executed. This document is a test contract, not test evidence.
