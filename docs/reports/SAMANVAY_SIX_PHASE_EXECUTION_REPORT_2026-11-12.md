# SAMANVAY — Six-Phase Execution and Readiness Report
**Audit date:** 12 November 2026 (Asia/Kolkata)  
**Repository:** `ur-saviour/SAMANVAY-Know-Below.-Dig-Above`  
**Branch audited:** `feature/alpha-03-integrated-platform`  
**Baseline commit:** `46d6ae18aaf7f22b8492c3db2a5c80b409e287ca`

## Executive finding

The six-phase roadmap has substantial database, application, and workflow foundations, but the live environment is not a complete operational municipal system. The production database currently contains no verified underground utility geometries, no registered survey evidence, no live road-cut permits, and no restoration inspections. Those gaps cannot be closed honestly by inserting synthetic records or treating reference datasets as authoritative infrastructure.

This report records completed engineering work, evidence-backed readiness, and the external conditions still required for real completion. “Implemented in source” is not treated as “validated in an operational pilot.”

## Phase 1 — Evidence and code audit

### Findings
- The last observed Android Actions run on the audited branch completed its build, Dart analysis, APK packaging and artifact checks. It did not validate real device login, GPS permission, map-tile delivery, file upload or role journeys.
- The in-app logo widget referred to `samanvay_logo_768_q76.webp`. The tracked binary was truncated: its WebP RIFF header declared 32,460 bytes while the stored file was 30,401 bytes. The fallback JPEG is only 176 × 176 pixels.
- The existing vector asset `samanvay_logo.svg` is a scalable, complete 512-viewBox brand mark. The in-app widget now renders this vector. The Android launcher artwork is generated from the same SVG at 768 × 768 pixels.
- The Android workflow now parses the SVG, renders it, decodes the resulting PNG, and verifies its dimensions before building. The truncated WebP is no longer declared as a Flutter asset or required inside the APK.
- Supabase Auth currently has six confirmed users and six matching profile rows: three `requester`, one `department`, one `coordinator`, and one `admin`. No orphan profile rows were found. The department account has a department assignment.
- Auth logs include successful password-grant responses (HTTP 200) as well as OTP failures tagged `otp_disabled`. This identifies an unsupported Email OTP path, not proof that every password login succeeds. Account-specific password credentials were not available for a controlled sign-in test.
- Email OTP and Mobile OTP controls are disabled in the app UI; password sign-in remains the default. Registration instructions now point to password sign-in. No auth policy or role authorisation was bypassed.
- The Android build for commit `9407827bd04d9a2e8e66a7b856abb57ca5c49323` passed Dart analysis, release compilation, APK package/signature/alignment checks and artifact upload. Artifact: `SAMANVAY-Alpha-0.3-APK` (44,274,779 bytes). The browser portal build and GIS smoke test also passed; its artifact is `SAMANVAY-Browser-Portal` (14,972,692 bytes). These are CI results, not on-device acceptance tests.

### Phase status
**Engineering actions and CI:** complete for the source patch; Android and browser workflows both passed.  
**Still required:** install the resulting APK on physical Android devices and test each authorised account, role route, map, GPS, and media workflow.

## Phase 2 — GIS and conflict detection

### Implemented foundations
- PostGIS schema for underground assets and survey evidence exists.
- A generalised public map-access path and staff-restricted exact-geometry path exist.
- A proximity-advisory function and ownership/verification controls exist. The advisory is horizontal and source-aware; it is not a vertical-clearance guarantee.
- The Phase 2 administrative hierarchy now contains 784 district rows, 7,092 sub-district rows and 7,312 unambiguous block rows from a 21 October 2026 community mirror snapshot of Ministry of Panchayati Raj LGD data. All remain `imported_unverified`.
- The database also contains 733 valid WGS84 generalized district reference polygons from a separate historical DataMeet-derived source; these are not current statutory polygons.
- The public geoBoundaries ADM1/ADM2 Edge Function remains a separate on-demand reference display path.

### Live data snapshot
| Dataset | Current rows / coverage |
|---|---:|
| 2026 community-mirrored LGD districts | 784 |
| 2026 community-mirrored LGD sub-districts | 7,092 |
| 2026 community-mirrored LGD blocks inserted | 7,312 |
| LGD block rows rejected for duplicate codes | 30 |
| State/UT parent records | 36 |
| Historical/generalized district reference polygons | 733 |
| Groundwater station observations | 446,068 |
| Groundwater observations with coordinates | 445,553 |
| State/UT labels in groundwater observations | 31 |
| `gis.underground_assets` | 0 |
| `gis.asset_survey_evidence` | 0 |

The community mirror's pinned source date is **21 October 2026**; it is 22 days old on the audit date and outside its documented 14-day freshness target. It is not a live Ministry connection. All imported hierarchy rows remain unverified. ULBs, wards, villages and panchayats are not part of this imported snapshot. The 30 rejected block records correspond to 15 duplicated LGD codes repeated under different district parents; both records for each duplicate code were withheld.

Groundwater observation dates range from **1 January 2025 through 31 December 2025**. The 515 non-geocoded observations must not be plotted as precise locations. The latest-per-station map view has 576 rows, of which 574 are geocoded. The groundwater register is not an underground water-pipeline map.

For the row-level audit, source hashes, import batch IDs, polygon validity checks and remaining blockers, see [the updated Phase 2 National GIS Data Import and Verification Report](SAMANVAY_PHASE_2_NATIONAL_REFERENCE_IMPORT_2026-11-12.md).

### Phase status
**Administrative-reference foundation:** substantially populated with a pinned LGD mirror snapshot and generalized public district geometry.  
**Operational status:** not complete until the LGD hierarchy is refreshed and authority-verified, missing local-body/ward data is acquired, competent utility owners supply authorised geometry, field evidence is accepted, and conflict screening is validated on independently reviewed cases. Until then, an empty utility registry must produce “data unavailable”, never “no conflict”.

## Phase 3 — Permits and interdepartmental coordination

### Implemented foundations
- Multi-domain work request categories and department routing suggestions exist.
- Department review, coordinator checks, status history and protected RPC-based status changes exist.
- Road-cut permit, deadline/compliance, schedule advisory, drainage inspection and road-restoration quality-gate schemas/functions are present.
- The joint-work proposal workflow is now deployed: proposal, department-response and event-history tables; participant-scoped RLS; and role-gated create/respond/finalise RPCs. Its boolean read-guard helper was moved to a non-API `private` schema so it is not exposed as a public PostgREST function. The existing browser/mobile coordination page now has its expected live backend.

### Live operational data
- Excavation requests: 4 rows.
- Department review records: 3 rows.
- Coordination-check records: 1 row.
- Repeated department assignment defect: fixed in the live RPC; repeated calls now return the existing review ID instead of raising a unique-key error.
- Road-cut permit records: 0 rows.
- Road-restoration records: 0 rows.
- Drainage inspection records: 0 rows.
- Public excavation notices: 1 draft row; notice events: 0 rows.
- Joint-work proposals/responses/events: 0 persistent rows after the rollback-only end-to-end regression test.

The existence of a request or review row does not establish statutory authorisation or prove a live joint-work agreement. A draft notice is not a published public notice.

### Duplicate-assignment defect repair and verification
The prior `public.assign_request_department` function inserted a new review row on every call. The table has a unique constraint on `(request_id, department_id)`, so assigning the same department twice raised a unique-key error. Migration `20261111222102_make_department_assignment_idempotent.sql` now uses `ON CONFLICT ... DO NOTHING` and returns the already-existing review ID. The admin/coordinator authorization check, request/department existence checks, SECURITY DEFINER setting, and empty search path remain in place.

A live database test ran as an authenticated administrator against an already-assigned request inside a transaction. The function returned the same ID as the stored review row (`returns_existing_assignment = true`); the matching row count remained one, and the test transaction was rolled back.

### Joint-work proposal migration and verification

Migration `20261112112501_add_joint_work_proposal_workflow.sql` was applied to the connected Supabase project and synchronised to the repository using the applied ledger version. It creates the proposal, department-response and event-history tables; participant read policies; and three RPCs for coordinator creation, department response and coordinator finalisation. The functions enforce role and state transitions, require distinct participating departments, prevent duplicate active case pairs and require all responses before scheduling.

A rollback-only authenticated regression test used two existing assigned department-review records. A coordinator created a proposal; the participating department account accepted each department response in turn; and the coordinator finalised a shared schedule. The observed result was `scheduled`, 2 response rows, 2 accepted responses and 4 event-history rows. The entire transaction was rolled back; no real proposal or operational schedule was created.

### Phase status
**Workflow foundation:** present; duplicate-assignment failure fixed and transaction-tested; joint-work backend deployed, private read-guard hardened and end-to-end role-tested in a rollback-only transaction.  
**Operational status:** incomplete until participating authorities exercise the permit, acknowledgement, rejection, escalation, joint-work and emergency-exception paths against authorised cases and statutory rules.

## Phase 4 — Field verification

### Implemented foundations
- Private asset-evidence upload and registration paths are present.
- Evidence access is restricted by role and ownership; survey evidence acceptance is separated from geometry verification.
- Road restoration and drainage inspection records have structured QA fields and database checks.
- Case inspections now support device-reported GPS coordinates, timestamp and horizontal accuracy, with coordinate-range and capture-state checks.
- Private site-photo evidence can be linked to an inspection and stores capture time, optional GPS metadata and a SHA-256 byte-integrity hash.
- The Case Workspace inspection form now offers optional GPS capture and camera photo capture; Android/browser workflows install the required Geolocator and Image Picker packages. GPS and camera permissions are requested at runtime where applicable.
- Case-attachment RLS requires the authenticated uploader, request-scoped storage path and a matching inspection owned by the submitting staff member when an inspection link is supplied.

### Live operational status
There are currently **0 case inspection rows**, **0 registered GIS survey-evidence rows**, **0 road-restoration records** and **0 drainage-inspection records**. The case-attachment table has 1 pre-existing row; no new evidence was persisted by the tests. The Phase 4 GPS/photo flow passed a rollback-only database RLS test, but no physical-device camera/GPS capture has yet been performed.

### Phase status
**Software foundation:** present; geotagged inspection schema deployed, private photo-link policy and UI capture path implemented. Android and browser automated release builds passed on app commit `174e05ce6b4082b00faf2061d308307f804c7c73`.  
**Operational status:** incomplete until physical Android/browser GPS and camera behaviour is tested and a department/contractor team performs field capture, records source drawings and positional confidence, uploads genuine evidence, reports discrepancies, and completes authorised restoration inspections. Offline behaviour remains untested.

## Phase 5 — Controlled pilot

No controlled municipal pilot can be declared complete from the current evidence. The repository does not contain an independently labelled utility-conflict test corpus, an approved participating-ward baseline, or measured before/after operating outcomes.

### Pilot acceptance plan
1. Authorise utility-owner maps, road ownership and permit registers for a defined ward/corridor.
2. Record baseline work volume, repeat road cuts, review latency, restoration defects and complaint age.
3. Run the workflow with named department focal points and trace every request, review, permit, field update and closure.
4. Compare outcomes to the baseline and publish failures, limitations and confidence intervals alongside any benefits.

Required KPIs: repeat cuts per road segment; request-review median and p90; alert precision/recall on independently labelled cases; owner response time; asset provenance and positional confidence; permit completeness; restoration rework; complaint age; and evidence-complete closures.

### Phase status
**Pilot design:** specified.  
**Pilot execution and measured impact:** not complete. No savings, prevention rate or conflict-detection accuracy is claimed.

## Phase 6 — Integration and expansion

### Implemented foundations
- India State/UT directory has 36 rows.
- The community LGD mirror provides 784 district, 7,092 sub-district and 7,312 imported block rows with source LGD codes; all remain unverified pending an authoritative refresh.
- A separate generalized district polygon reference contains 733 valid WGS84 geometries.
- National authority, source and data-coverage registries exist.
- Data-acquisition and jurisdiction metadata structures are present.

### Live readiness gaps
- National ULB, ward, village, gram-panchayat and traditional-local-body hierarchy is not complete.
- The community mirror snapshot is dated 21 October 2026 and is outside its documented 14-day freshness target on the audit date.
- No complete authoritative state → district → sub-district → ULB → ward → village geometry hierarchy is present.
- There is no evidence here of signed data-sharing agreements, owner-specific underground-asset import authorisations, completed integration credentials, or production interoperability tests with municipal/utility systems.
- National groundwater observations and historical district reference polygons do not substitute for national underground utility GIS.

### Phase status
**National administrative-reference scaffolding:** materially advanced, with source dates, code provenance and import-batch audits.  
**Operational national coverage and integrations:** incomplete; must be delivered incrementally with current authority data, data-owner agreements, validated feeds, source attribution, update SLAs and access controls.

## Security and release controls

Current Supabase security-advisor findings after the Phase 3/4 migrations are 18 authenticated-callable SECURITY DEFINER function warnings and one Auth warning for disabled leaked-password protection. The 18 includes three intentional joint-work RPC endpoints with explicit role checks; the joint-work RLS read guard is in the non-API `private` schema. Each SECURITY DEFINER routine still requires individual review; do not “fix” warnings by indiscriminately granting access or removing RLS. Leaked-password protection remains an outstanding Auth setting.

The application must be revalidated after this patch on a physical Android device. A successful CI build is necessary but not sufficient for release acceptance.

## Phase 3/4 automated release verification — 12 November 2026

The Phase 3/4 Flutter code and workflow dependency changes were built from app commit `174e05ce6b4082b00faf2061d308307f804c7c73`.

| Target | Workflow | Result | Artifact |
|---|---|---|---|
| Android Alpha 0.3 | [43210697754](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43210697754) | Success: analysis, release build, ABI split, package/signature/alignment checks and publication | [Artifact 13941566669](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13941566669/zip) |
| Browser portal | [43210698178](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43210698178) | Success: analysis, browser release build, GIS asset smoke tests and packaging | [Artifact 13941171647](https://api.github.com/repos/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/artifacts/13941171647/zip) |

- Android artifact SHA-256: `1106cc8031077c2c37c535cd2e5e950ee9c49eebf0b0ef60c8ce5b673eb50f79` (44,563,969 bytes).
- Browser artifact SHA-256: `29c040ce34c6c27cba906eb58451279b5e912534a0542150490424681a5bfa09` (14,988,268 bytes).
- Both downloaded ZIPs matched the GitHub artifact digests and passed archive integrity checks. The browser inner deployment ZIP also passed integrity checks.
- ARM64 APK extracted from the Android bundle: SHA-256 `0a1652732781f42e761fc05dea0c365037744e8c925789a1a5a4fe3b502f49e6`; APK archive integrity passed.
- Automated builds do not validate a real handset's GPS/camera permissions, GPS accuracy, camera capture, network upload or offline recovery. Those remain physical-device acceptance tests.

## Final status

| Phase | Software foundation | Operational completion |
|---|---|---|
| 1. Evidence and code audit | Vector branding, OTP UI correction, image decode checks; Android + browser CI passed | Physical-device login, role, map, GPS and media validation remains |
| 2. GIS and conflict detection | 784 districts, 7,092 sub-districts, 7,312 blocks, 733 generalized district polygons, groundwater reference and role-restricted GIS code | Blocked by 0 owner-authorised underground assets, 0 survey evidence, incomplete ULB/ward/village hierarchy, stale mirror snapshot and pending device/field validation |
| 3. Permits and coordination | Workflow/RPC foundations present; joint-work proposal backend deployed and rollback-tested; idempotent assignment RPC fixed | Blocked by 0 live joint-work proposals, permits, restoration records and authority validation |
| 4. Field verification | Device-GPS inspection metadata, private photo linkage and hash capture implemented; rollback-only RLS test passed | Blocked by 0 live inspections/asset survey evidence, physical-device testing and owner-authorised field data |
| 5. Controlled pilot | Pilot protocol and KPIs specified | Not run; no authorised cohort or measured baseline |
| 6. Integration and expansion | 36 State/UTs; LGD mirror hierarchy and district reference polygons imported | Blocked by missing ULB/ward/village records, current authority refresh, agreements and tested integrations |

**Conclusion:** Phase 1 source fixes are committed and both CI pipelines passed; the Phase 3 duplicate-assignment RPC fix is deployed and transaction-tested. Phases 2–6 cannot truthfully be marked 100% operationally complete until official asset owners, municipal authorities, field teams, integration credentials and a measured pilot are available. No synthetic utility geometry, fake approval, false field evidence or unmeasured savings has been introduced by this execution.
