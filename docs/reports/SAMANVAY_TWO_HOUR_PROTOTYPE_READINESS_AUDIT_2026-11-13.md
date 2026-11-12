# SAMANVAY — Two-Hour Prototype Readiness Check

**Audit date:** 13 November 2026  
**Repository:** `ur-saviour/SAMANVAY-Know-Below.-Dig-Above`  
**Branch:** `feature/alpha-03-integrated-platform`  
**Supabase project:** `zhtotivedvkmclerdnlf`

## Verified starting state

### Build and release

Latest Alpha 0.3 Android and browser builds passed on app source commit `01ad3154f501b409a1376626bb14d1f80ddf0197`.

- Android run: [43288750400](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43288750400) — success.
- Browser run: [43288750376](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43288750376) — success, including GIS bundle smoke tests.
- ARM64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-arm64-v8a.apk), 33,824,275 bytes, SHA-256 `928232f04b848d4ef476010de0a632a33f9f39bccf4f7b8e68a615b0864f58c5`.
- ARMv7 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-armeabi-v7a.apk), 28,913,277 bytes, SHA-256 `3b365a9726e10b4e89e31b202f02693b79bc270e6668be305a4aa6175f2c616a`.
- x86_64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-x86_64.apk), 35,610,484 bytes, SHA-256 `62121afbe864e37f326976f07d9f9eeab986b04a08d97490d4f036a445045bba`.
- The Android build workflow checks package name, APK ZIP integrity, signing certificates, zip alignment and required brand / Coimbatore GIS assets.

### Role and operational data inventory

Live role counts:
- 1 administrator
- 1 coordinator
- 1 department officer with a department assignment
- 3 Citizen/requester accounts

The role-change RPC has been tested in rollback-only transactions:
- Coordinator role change denied.
- Administrator self-role change denied.
- Administrator assignment RPC returned normally for a valid target and department; transaction rolled back after test.

Live operational table counts:

| Object | Rows |
|---|---:|
| Departments | 11 |
| Excavation requests | 4 |
| Department reviews | 3 |
| Coordination checks | 1 |
| Case messages | 1 |
| Case attachments | 1 |
| Public excavation notices | 1 |
| Joint-work proposals / responses | 0 / 0 |
| Road-cut permit records | 0 |
| Road-restoration records | 0 |
| Inspections | 0 |
| Underground assets / survey evidence | 0 / 0 |

All four live excavation requests are currently `submitted`. The more complete permit, inspection, joint-work and restoration lifecycle is available in the clearly labelled local demonstration workspace, not as a claim that those database operations already have real data.

### GIS and administrative data

- 36 State / UT parent records.
- 396 jurisdiction/domain readiness records across 11 domains.
- 20,238 imported district, sub-district, block and ULB reference records; all remain unverified.
- 0 operationally authorised utility layers and 0 verified underground assets.
- 5,050 ULB-to-district reconciliation rows; all remain `unmapped`.
- Duplicate LGD codes: 0 in audited non-null code groups.
- Orphaned parent IDs: 0 in the audited hierarchy.
- 5,050 ULBs have no district parent because their source did not provide district mapping.

The India GIS/coverage view now shows these facts and distinguishes reference data from certified and operational records.

### Groundwater integrity

The live groundwater observation table currently contains 446,068 calendar-2025 rows and 0 records outside 2025. The original 1,911,126-row encrypted pre-change archive was validated by the 9 November workflow before the production truncate.

All four destructive legacy recovery workflows have been removed from the active feature branch. The new `verify-groundwater-archive.yml` is manual-only and restores the archive into disposable local PostgreSQL, without Supabase production credentials or production writes.

**Not yet run:** the archive verifier requires a manual GitHub Actions dispatch. The connected GitHub actions interface used for this audit does not expose a workflow-dispatch action, and the repository's browser profile has no saved GitHub sign-in. No production restore has been attempted.

## Two-hour sprint work completed in this pass

1. Rechecked the branch build and database starting state.
2. Re-audited map code for vector / satellite basemaps, 2D / 3D building extrusions, owner-scoped asset layers, public aggregate cells, groundwater telemetry and region navigation.
3. Rechecked sign-in error messaging, session validation and profile switching. Demo profile switching opens local sample workspaces; it does not impersonate database roles.
4. Re-tested role authorization, ULB queue access and evidence requirements using rollback-only SQL.
5. Confirmed the latest ABI APKs and browser portal are successfully built and published as release assets.
6. Added a five-minute jury demonstration runbook and documented the exact claims / limitations to use.

## Remaining actions which require external or device access

1. Manually dispatch `verify-groundwater-archive.yml` in GitHub Actions and inspect its full archive validation result.
2. On an actual Android device, test login and password reset, profile navigation, GPS permission, satellite tile loading, camera / evidence uploads, notifications and offline handling.
3. Restore historical groundwater rows only after isolated archive verification and a separate approved additive-delta plan.
4. Obtain authorised LGD exports and mapping sources; do not bypass portal CAPTCHA and do not infer ULB parents.
5. Obtain actual owner-department utility geometry and survey evidence before claiming underground asset coverage.
6. Run a measured pilot only after an authorised municipal cohort, baseline and evidence protocol exist.

## Completion estimate

The engineering planning estimate remains **74% prototype completion**. The two successful release pipelines, ULB reconciliation interface and demo runbook improve demonstrability, but the percentage is not raised for actions that still require external authorisation, manual GitHub dispatch or physical-device acceptance.

This sprint check makes no claim of 95% completion, production readiness or completed groundwater restoration.
