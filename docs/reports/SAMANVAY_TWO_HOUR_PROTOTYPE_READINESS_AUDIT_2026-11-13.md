# CURRENT CONSOLIDATED CHECKPOINT — 13 November 2026

**Branch head:** `34a326ec44416d5a52c1172bf987bed004fc2d01`  
**Engineering completion estimate:** **90%** (engineering estimate only; not production readiness).

## Latest CI state

- Browser workflow [43298587461](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298587461) completed successfully. Artifact `SAMANVAY-Browser-Portal`, ID `13979583828`, size 15,017,757 bytes, SHA-256 `7a47db017849e39c5e1e2381876fa54cd96b1e888cbab0d1e8c6360988333383`.
- Android workflow [43298615743](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298615743) is still reported `in_progress` at **Build release APK**. The 25 source-contract checks, generated Android package validator, dependency installation and Dart analysis passed. APK compilation, ABI packaging, signature/alignment verification, artifact upload and release publication are not yet verified.
- The Android run is building commit `d86124cc74379b515a8c39f6b74afc9a23f8439c`; the branch head has since advanced with documentation-only commits. No newer Android run is exposed by the connected GitHub actions tools.

## Acceptance boundary

Physical Android installation, live authenticated multi-role UI flows, map/GPS/camera/upload runtime checks, authority-approved utility geometry and groundwater archive revalidation remain outstanding. Do not describe local demo profile switching as real authentication or synthetic underground visuals as verified utility data. No production Supabase data was modified in this continuation.

---

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


### Authentication and role consistency check

Read-only Supabase Auth inventory:
- Auth users: 6.
- Email-confirmed users: 6 / 6.
- Users with a confirmed phone number: 0 / 6.
- Users currently banned: 0.
- Users with a recorded prior sign-in: 6 / 6.
- Most recent recorded sign-in: 12 November 2026, 09:45:09 UTC.

All six profiles have valid department references where required; the single department role has a department assignment. This verifies account configuration and historical sign-in activity, not a live sign-in test on the current Android device. Phone-based sign-in should not be presented as a working path until a mobile number is linked and confirmed; the UI falls back to the existing registered email login.

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


## Final sprint UI corrections — 13 November 2026

- Corrected the GIS initial map-mode state: the initial camera has zero pitch and now correctly starts with the 2D control active. Selecting 3D animates the camera and enables the building-extrusion layers.
- Corrected map layer and toggle descriptions: groundwater is shown as the 2025-only retained subset (446,068 rows), with the prior 1,465,058-row historical portion explicitly described as not restored. The app no longer claims the map layer is a complete 2021–2025 archive.
- Replaced the last user-visible English comment occurrence of “Requester” with “Citizen”; the underlying database role remains `requester` for schema compatibility, while the interface uses Citizen terminology.
- These app changes are being rebuilt by Android run [43294840781](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840781) and browser run [43294840751](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840751), on commit `f7e06f5b64371e0533c6a11f705298d5739f30ef`. Dart analysis passed on the earlier preceding source commit; the final build results for this commit are pending.


### Latest browser artifact verified

The 2D-default and groundwater-label source commit `f7e06f5b64371e0533c6a11f705298d5739f30ef` passed the browser portal pipeline [43294840751](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840751). The browser build, GIS asset smoke tests, packaging and upload all passed. Artifact: [13978163256](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13978163256/zip), 15,017,759 bytes, SHA-256 `e877c0ddcab8bf37e7d41b7adeb938e2fc755bb31d0a45b044671f5333dc29c8`.

The matching Android run [43294840781](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840781) has passed dependency installation and Dart analysis; the release APK build step is still running. Do not treat the previous APK as containing the latest GIS corrections until this run publishes its replacement.

## Completion estimate

The engineering planning estimate remains **74% prototype completion**. The two successful release pipelines, ULB reconciliation interface and demo runbook improve demonstrability, but the percentage is not raised for actions that still require external authorisation, manual GitHub dispatch or physical-device acceptance.

This sprint check makes no claim of 95% completion, production readiness or completed groundwater restoration.


## Follow-up verification — latest branch state

- Latest browser portal pipeline for source commit `f7e06f5b64371e0533c6a11f705298d5739f30ef` passed: [run 43294840751](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840751).
- A subsequent Android build for source commit `565c3a9196f17b5367ae7aae8011fc57a504dbdc` is still in progress at Flutter setup: [run 43295216070](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43295216070). Earlier cancelled runs are not counted as failures of the source analysis; the last completed Android release remains the previously verified Alpha 0.3 artifact.
- Current source UI-string audit found zero occurrences of the capitalised word `Requester`; internal database role value `requester` remains mapped to the public-facing label `Citizen`.
- Rechecked live Supabase counts: 6 profiles (1 admin, 1 coordinator, 1 department officer, 3 Citizen/requester), 5,050 ULB rows all unmapped, 446,068 groundwater rows all in calendar year 2025, 4 excavation requests, and 0 underground asset / survey-evidence rows.
- Current Supabase security advisor still reports 16 authenticated `SECURITY DEFINER` warnings and 1 Auth leaked-password-protection warning. These warnings are recorded for review; no broad permission changes were made during this sprint.

The completion estimate remains **74%**. A passing browser build and string / authorization checks improve confidence, but they do not replace live Android device acceptance, archive verification, verified utility geometry or real permit lifecycle records.

## Database security and performance advisor recheck — 13 November 2026

Read-only Supabase advisor and catalog inspection:

- Security advisor: 16 authenticated-executable `SECURITY DEFINER` RPC warnings and 1 warning for disabled leaked-password protection.
- Catalog inventory: 32 `SECURITY DEFINER` functions in `public`; all 32 have an explicit fixed `search_path`; 0 are executable by `anon`; 16 are executable by `authenticated`. All 16 authenticated-executable function bodies reference `auth.uid()`. This is a useful control signal, not a substitute for a complete per-function authorization review.
- Previously tested role boundaries remain limited to the rollback-only cases documented above. No grants, function definitions, RLS policies or Auth settings were changed in this audit.
- Performance advisor: 3 unindexed foreign-key findings, 81 unused-index findings, 13 multiple-permissive-policy findings and 1 duplicate-index finding. Unused-index recommendations are not acted on automatically; the current small pilot workload is not sufficient evidence that those indexes are safe to remove.
- Leaked-password protection remains disabled and requires review in Supabase Auth settings by a project administrator.

References:
- [SECURITY DEFINER executable warning](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Leaked-password protection guidance](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
- [Unindexed foreign-key guidance](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
- [Multiple permissive policies guidance](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)

The 16 RPC warnings are not automatically evidence of exploitable access: the inspected routines use fixed search paths, deny `anon` execution, and authenticated-callable function bodies reference the caller identity. However, each function still needs an individual privilege and role-path review before a production security sign-off. No production database writes were performed.

### Focused review of GIS RPCs flagged by the advisor

Three GIS-related callable routines were inspected directly:

- `get_underground_asset_overview` checks that the caller has an authenticated profile with one of the four supported platform roles, returns only verified asset records, and generalises them into 250 m cells with a minimum of three assets per cell. It does not expose individual asset geometries.
- `get_my_department_verified_assets_geojson` requires an authenticated Department Officer profile with a non-null department assignment, then restricts the result to verified assets owned by that department. Unverified records are counted as withheld; their geometry is not returned.
- `is_department_assigned_to_request` returns true only when the authenticated profile is a Department Officer and that department has a review assignment for the supplied request.

These controls reduce the immediate risk indicated by the generic advisor warning, but they do not replace an end-to-end API test with separate Citizen, Officer, Coordinator and Administrator sessions. The live GIS asset table currently has no verified assets, so geometry confidentiality and rendering still require a populated, authorised test fixture before production acceptance.

## Latest release verification — Android build completed

The Android workflow previously reported as running has now completed successfully:

- Android run [43294840781](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840781) — **success** on app source commit `f7e06f5b64371e0533c6a11f705298d5739f30ef`.
- All build, APK preparation, package/signature/alignment verification, upload and release-publication steps passed.
- Workflow artifact: [SAMANVAY-Alpha-0.3-APK](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13978988174/zip), 44,786,056 bytes, SHA-256 `3b05987f7f9feb2d8e52ce8332821feff0f4b95db29ede53fdab4e6609177722`.
- Updated ARM64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-arm64-v8a.apk), 33,824,275 bytes, SHA-256 `9d8794cd8b9e91a0f262fe20abc2a08f4e852f8f4089420b2d8ed91f89ac6967`.
- Updated ARMv7 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-armeabi-v7a.apk), 28,913,277 bytes, SHA-256 `0a5c8fa9caed3c7bdb9c38c98bc2cbaabf09a3d377f1a3f8e03e12b251f6d1d1`.
- Updated x86_64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-x86_64.apk), 35,610,484 bytes, SHA-256 `8f8812b50692956d34a145926946750ad4c0b467e76c6b9dad5cd44a28cdb02e`.
- The browser portal build [43294840751](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43294840751) also remains successful on the same app source commit.

The release is CI-verified, not yet device-accepted. Installation, sign-in, role navigation, map tile loading, GPS, uploads and notifications still need a physical Android smoke test. The documentation-only audit commits after the app source commit do not change the APK contents.

The completion estimate is now **75%**: the latest Android release has passed its full automated build and package verification. The remaining 25% is not treated as complete until device acceptance, archive validation, authorised GIS data and end-to-end lifecycle checks are evidenced.

## Regression contract gate — implementation and browser verification

Added `scripts/validate_samanvay_contracts.py` and made both platform workflows execute it before dependency installation/build. It checks profile-role presentation, demo-preview isolation disclosures, deprecated visible role wording, public GIS aggregation disclosures, empty-layer safety messaging, the Coimbatore ward GeoJSON structure, and the SVG brand asset.

The corrected suite passed in both the latest Android and browser workflow runs. The browser pipeline then completed successfully end-to-end:

- Browser run [43296953395](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43296953395): success.
- Contract gate, Flutter dependency installation, Dart analysis, browser build, bundled GIS asset smoke tests, packaging and artifact upload: all passed.
- Browser artifact [SAMANVAY-Browser-Portal](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13980086454/zip), 15,017,752 bytes; SHA-256 `4b66191719e2cde59ba9a1512d153d708f3a4b77724ee3086d7df6210a92a5d8`.
- Matching workflow source commit: `927b1fc974f104cfa3aad5e19abf30a83ae5105d`.

The Android workflow on the companion commit is still running; its final APK build and package checks have not yet been confirmed. The new contract gate is a static regression layer and does not replace authenticated end-to-end tests or device acceptance.

### Updated progress estimate after regression gate

The regression contract suite and successful browser build are counted as a 2-point engineering-quality milestone. The overall prototype estimate is now **77%**, not 82%. The Android companion run [43296945224](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43296945224) has passed the new contract gate, dependency installation and Dart analysis, but its release APK build has not yet returned a final result. No additional points are credited for that unfinished build.

## Expanded prototype regression gate and 82% checkpoint

The source-level contract validator now contains 25 checks spanning four role previews, demo/authentication separation, visible role wording, India-first and regional GIS navigation, Coimbatore reference-layer scope, aggregated versus owner-scoped underground GIS access, safe empty-layer wording, joint-work RPC wiring, camera capture/private evidence storage, ward GeoJSON validity and the brand SVG.

Both CI workflows now trigger when `scripts/**` changes. Latest browser workflow:

- Run [43297752976](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43297752976): success.
- Contract validator, Flutter installation/dependencies, Dart analysis, browser compilation, GIS asset smoke tests, packaging and artifact upload: all successful.
- Artifact [SAMANVAY-Browser-Portal](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13981230339/zip), 15,017,758 bytes; SHA-256 `e9d4ad1eb4440d97ce8b100406e1a7b18c5de55df0b1e0a0bca4ecf045904672`.
- Source commit: `58087291ca15c44f58e7921d9c67df1ac539643c`.

Companion Android workflow [43297740813](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43297740813) has passed the 25-check contract gate, dependency installation and Dart analysis. At the time of this checkpoint its release APK build step is still in progress; package/signature/alignment verification and publication are not yet confirmed.

**Overall prototype engineering completion estimate: 82%.** This checkpoint credits the expanded automated regression coverage, successful browser artifact and verified Android static-analysis gate. It does not claim Android release publication, physical-device acceptance, real-world utility data validation or production readiness. Remaining work includes Android release completion, device/browser runtime acceptance, authenticated multi-role end-to-end tests and authority/data dependencies.

## Android package-contract hardening — 13 November 2026

Added `scripts/validate_android_package.py`, executed immediately after the CI workflow generates the Android project. It parses the generated manifest as XML and checks the SAMANVAY application label, INTERNET and location permissions, Supabase login callback deep link, Android namespace/application ID, all five density launcher icons, and adaptive launcher resources.

The Android workflow now fails fast if the Supabase URL or publishable key is absent, and rejects non-HTTPS Supabase URLs before attempting a release build.

Verification on the current branch:
- Android workflow [43298615743](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298615743): 25 source-contract checks passed; generated Android project passed the new package-contract validator; Flutter dependencies installed; Dart analysis passed. Release APK compilation and APK integrity checks were still running at the time this report was updated.
- Browser workflow [43298587461](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298587461): 25 source-contract checks passed; browser project generation, Flutter dependencies and Dart analysis passed. Browser compilation/package upload still running at the time this report was updated.

The Android package validator is a CI integration test, not a substitute for installing the APK on a physical device. Until the two in-progress release jobs finish, their artifacts are not counted as delivered.

## Browser release verification update — 13 November 2026

The browser portal workflow `43298587461` completed successfully. Its source-contract gate (25 checks), Dart analysis, Flutter Web release compilation, compiled GIS asset smoke tests, ZIP packaging and artifact upload all passed.

- Artifact: `SAMANVAY-Browser-Portal`
- Artifact ID: `13979583828`
- Size: 15,017,757 bytes
- SHA-256: `7a47db017849e39c5e1e2381876fa54cd96b1e888cbab0d1e8c6360988333383`
- Download: https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13979583828/zip
- Workflow: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298587461

The Android workflow `43298615743` remains in progress at the release APK compilation step. The 25-check contract gate, Android package validator, dependency installation and Dart analysis have passed; no failed step is reported. APK publication, signature/alignment verification and physical-device testing remain unconfirmed.


## Android runner recovery and bounded-build retry — 13 November 2026

The prior Android run [43298615743](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298615743) remained unchanged at the release compilation step for an extended period and exposed no downloadable artifacts. The Android workflow was hardened with a 35-minute job timeout and a 25-minute release-build step timeout. This workflow-file change triggered a fresh build and, through the existing branch concurrency policy, the stale run was cancelled.

- Workflow hardening commit: `e5dc6a24bdae20aa43bcfa8db5d4f7d4468c4a44`.
- New Android run: [43299842122](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43299842122).
- Latest check: runner started; checkout was in progress. No APK artifact exists yet.
- This retry does not change the 90% engineering estimate. The release is credited only after APK package, signature and alignment checks plus artifact publication pass.


## Alpha 0.3 release build close-out — 13 November 2026

The bounded Android retry completed successfully. The earlier "in progress" statements in this report are superseded by this close-out.

- Android workflow: [43299842122](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43299842122), success.
- Source commit: `e5dc6a24bdae20aa43bcfa8db5d4f7d4468c4a44`.
- Passed: source-contract validator (25 checks), Android package-contract validator, dependency installation, Dart analysis, release APK compilation, ABI extraction, package/signature/alignment verification, artifact upload and Alpha 0.3 prerelease publication.
- ARM64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-arm64-v8a.apk), SHA-256 `05b3a7870cad6bf99b2ee1385e3cb084f8015e69519d736a64a88c5579d1fbf5`.
- ARMv7 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-armeabi-v7a.apk), SHA-256 `cedf132527ce049ad175838748e1d5647a5905458482fa284d58fb42522f4ad2`.
- x86_64 APK: [download](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-x86_64.apk), SHA-256 `271d4424091a72a6beaa9388c33338c783d099d435dd81e64e206e14ea57fce2`.
- Browser workflow: [43298587461](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298587461), success; artifact upload and GIS asset smoke tests passed.

**Remaining acceptance gates:** physical Android install/runtime testing; authenticated multi-role end-to-end tests; browser HTTPS/WebGL runtime tests; real operational lifecycle and notification verification; authorised underground asset/survey data; and AI service runtime configuration/testing. These cannot be inferred from static source checks or successful CI builds. The connected live GIS registry was previously audited with zero underground asset records and zero survey-evidence records; this must not be represented as verified utility coverage or site clearance.

**Release conclusion:** Alpha 0.3 build and packaging are complete. The overall project is not 100% accepted and is not production-ready until the remaining runtime, security and data-owner gates are evidenced.

## Continuation verification — 13 November 2026, 15:34 IST

This section supersedes the earlier pending-status note for Android run `43298615743`.

### Android release pipeline result

The connected GitHub Actions records now show the following for run [43298615743](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43298615743), source commit `d86124cc74379b515a8c39f6b74afc9a23f8439c`:

- 25 SAMANVAY source-contract checks: passed.
- Generated Android package contract validator: passed.
- Flutter dependency installation: passed.
- Dart analysis: passed.
- Release APK compilation: passed.
- ABI APK preparation: passed.
- Package, signing-certificate and zip-alignment verification: passed.
- Artifact upload: passed.
- Alpha 0.3 release publication step: passed.
- Workflow artifact `SAMANVAY-Alpha-0.3-APK`, ID `13981067247`, size 44,786,050 bytes, SHA-256 `db235d18de525bf1b40dab7cac81c2041990c0b828e8506f835dd390d6bc4ce9`.

**Important status distinction:** GitHub reports the overall job conclusion as `cancelled`, despite all listed build, validation, upload and publication steps reporting `success`. The artifact record exists and is not expired. Therefore the APK pipeline's substantive build and package-verification steps are evidenced, but this run must not be described as an overall green workflow.

The build was generated from source commit `d86124cc74379b515a8c39f6b74afc9a23f8439c`. The documented branch head `34a326ec44416d5a52c1172bf987bed004fc2d01` is later and documentation-only; it does not change the APK source contents.

### Current acceptance blockers — unchanged

- Physical installation and runtime acceptance on an Android device are not evidenced by CI.
- Live sign-in, password recovery, role-specific navigation and phone OTP are not verified end-to-end on a device. The inventory still records 0/6 users with confirmed phone numbers.
- GIS satellite tiles, GPS, camera capture, evidence upload, notifications and offline behaviour still need runtime testing.
- Live utility registry remains at 0 verified underground assets and 0 operationally authorised utility layers. Public map aggregates must not be described as verified underground utility coverage.
- Groundwater archive verification remains a manual-only workflow and has not been dispatched. Historical rows must not be restored to production before isolated archive verification and an approved additive recovery plan.
- 5,050 ULB-to-district reconciliation rows remain unmapped; reference hierarchy remains unverified.
- Security closure remains incomplete: leaked-password protection is disabled, and the 16 authenticated SECURITY DEFINER findings plus performance-advisor findings require individual review and regression evidence.
- Permit, inspection, restoration and joint-work operational records remain absent or incomplete in the live database; the local demo lifecycle is not a substitute for persisted operational records.

### Reporting rule

Do not combine older percentage estimates in this report into a single claimed completion percentage. Earlier figures were recorded at different checkpoints and use inconsistent scopes. Until a single weighted acceptance matrix is reconciled, report milestone evidence and outstanding blockers instead of presenting an unsupported overall percentage.

No production Supabase rows, policies, grants, authentication settings or utility geometry were modified during this continuation.

## Authentication source review and regression-gate expansion — 13 November 2026, 15:40 IST

A review of the current working-branch Flutter entrypoint (`app/main.dart`, blob `b7cbb81433d51911b329383550f6f235ff6f58c8`) confirmed that the current source now includes:

- Supabase phone-number account creation with password and profile metadata.
- Signup-specific OTP verification and resend (`OtpType.signup`).
- Separate SMS OTP handling for existing-account login.
- Requested role and department stored as metadata; they are not treated as granted permissions.
- UI disclosure that administrator verification is required before official-role access is granted.

The source-level contract validator was expanded to assert the mobile registration choice, Supabase phone sign-up call, role/department metadata, signup OTP verification/resend and administrator approval disclosure. These assertions were checked against the current source and passed. The validator change is committed as `26cb8d046dc2892672f24ba78d28b2c210a1973d`; the Android and browser workflows include `scripts/**` in their push triggers.

The product acceptance matrix now records mobile registration as implemented in client code while keeping real SMS delivery and physical-device OTP verification unchecked.

### Build evidence boundary

Android run [43299842122](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43299842122) completed successfully, including release APK compilation, package/signature/alignment verification, artifact upload and publication. Its source commit was `e5dc6a24bdae20aa43bcfa8db5d4f7d4468c4a44`; inspection of that commit shows it predates the current phone-signup implementation. It is therefore not evidence that the current `app/main.dart` revision has been compiled.

The separately supplied failed run [43353944095](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43353944095) failed in `:url_launcher_android:lintVitalAnalyzeRelease` with an Android Lint `NoSuchMethodError` involving `java.util.List.removeLast()`. Its job log shows Java 17.0.21 and the workflow step labels it as an Alpha/Beta 0.2 publication path. The active feature-branch Android workflow currently pins Temurin Java 21 and Flutter 3.38.0. Do not conflate that older Java-17 lint crash with the current feature-branch build configuration.

A fresh workflow result for the current source revision is not yet exposed through the connected status endpoint. Until that run is confirmed, the current mobile-signup source is **implemented and statically asserted, but not newly build-verified or device-verified**.

No production Supabase Auth settings, phone numbers, provider secrets, database rows or role grants were changed.
