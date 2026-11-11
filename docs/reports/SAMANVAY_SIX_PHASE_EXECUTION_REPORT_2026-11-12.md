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
- The existing vector asset `samanvay_logo.svg` is a scalable, complete 512-viewBox brand mark. The in-app widget is being switched to this vector. The Android launcher artwork will be rendered from the same SVG at 768 × 768 pixels.
- The previous workflow only checked that the WebP file existed and generated launcher icons from the 176 × 176 JPEG. The workflow is being changed to parse the SVG, render it, decode the resulting PNG, and verify its dimensions before building.
- Supabase Auth currently has six confirmed users and six matching profile rows: three `requester`, one `department`, one `coordinator`, and one `admin`. No orphan profile rows were found. The department account has a department assignment.
- Auth logs include successful password-grant responses (HTTP 200) as well as OTP failures tagged `otp_disabled`. This identifies an unsupported Email OTP path, not proof that every password login succeeds. Account-specific password credentials were not available for a controlled sign-in test.
- Email OTP and Mobile OTP controls are being disabled in the app UI; password sign-in remains the default. Registration instructions are being aligned with password sign-in. No auth policy or role authorisation is being bypassed.

### Phase status
**Engineering actions in this patch:** vector logo restoration, matching vector-based launcher generation, image decode checks in CI, and removal of misleading OTP choices.  
**Still required:** install the resulting APK on physical Android devices and test each authorised account and all role routes.

## Phase 2 — GIS and conflict detection

### Implemented foundations
- PostGIS schema for underground assets and survey evidence exists.
- A generalised public map-access path and staff-restricted exact-geometry path exist.
- A proximity-advisory function and ownership/verification controls exist. The advisory is horizontal and source-aware; it is not a vertical-clearance guarantee.

### Live data snapshot
| Dataset | Current rows / coverage |
|---|---:|
| `gis.underground_assets` | 0 |
| `gis.asset_survey_evidence` | 0 |
| Groundwater station observations | 446,068 |
| Groundwater observations with coordinates | 445,553 |
| State/UT labels in groundwater observations | 31 |
| State/UT directory rows | 36 |
| India administrative boundary-unit rows | 0 |

Groundwater observation dates range from **1 January 2025 through 31 December 2025**. The latest import timestamp is **9 November 2026**; an import timestamp does not make the underlying 2025 observations real-time. The 515 non-geocoded observations must not be plotted as precise locations.

The groundwater register is not an underground water-pipeline map. State/UT directory metadata is not district, city, ward or street boundary geometry. Utility-layer catalogue entries and source-registry entries are metadata, not accepted utility assets.

### Phase status
**Software foundation:** present.  
**Operational status:** not complete until the competent water, sewer, drainage, power, telecom, gas and road owners supply authorised maps; each import is validated, provenance-tagged and verified by survey. Until then, an empty registry must produce “data unavailable”, never “no conflict”.

## Phase 3 — Permits and interdepartmental coordination

### Implemented foundations
- Multi-domain work request categories and department routing suggestions exist.
- Department review, coordinator checks, status history and protected RPC-based status changes exist.
- Road-cut permit, deadline/compliance, schedule advisory, drainage inspection and road-restoration quality-gate schemas/functions are present.

### Live operational data
- Excavation requests: 4 rows.
- Department review records: 3 rows.
- Coordination-check records: 1 row.
- Road-cut permit records: 0 rows.
- Road-restoration records: 0 rows.
- Drainage inspection records: 0 rows.
- Public excavation notices: 1 draft row; notice events: 0 rows.

The existence of a request or review row does not establish statutory authorisation or prove a live joint-work agreement. A draft notice is not a published public notice.

### Phase status
**Workflow foundation:** present.  
**Operational status:** incomplete until participating authorities exercise the permit, acknowledgement, rejection, escalation, joint-work and emergency-exception paths against authorised cases and statutory rules.

## Phase 4 — Field verification

### Implemented foundations
- Private asset-evidence upload and registration paths are present.
- Evidence access is restricted by role and ownership; survey evidence acceptance is separated from geometry verification.
- Road restoration and drainage inspection records have structured QA fields and database checks.

### Live operational status
There are currently **0 registered GIS survey-evidence rows** and **0 operational restoration / drainage inspection rows**. No field survey or post-restoration acceptance is evidenced by the current database snapshot.

### Phase status
**Software foundation:** present.  
**Operational status:** incomplete until a department/contractor team performs field capture, records source drawings and positional confidence, uploads evidence, reports discrepancies, and completes authorised restoration inspections. Offline behaviour and real GPS/photo capture still require device testing.

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
- India state/UT directory has 36 rows.
- National authority, source and data-coverage registries exist.
- Data-acquisition and jurisdiction metadata structures are present.

### Live readiness gaps
- India administrative-unit table currently has 0 rows.
- No complete authoritative state → district → city → ward geometry hierarchy is present in the live administrative-unit table.
- There is no evidence here of signed data-sharing agreements, owner-specific import authorisations, completed integration credentials, or production interoperability tests with municipal/utility systems.
- National groundwater observations do not substitute for national underground utility GIS.

### Phase status
**National metadata scaffolding:** present.  
**Operational national coverage and integrations:** incomplete; must be delivered incrementally with data-owner agreements, validated feeds, source attribution, update SLAs and access controls.

## Security and release controls

Supabase security advisories include a SECURITY DEFINER verification-queue view, authenticated-executable SECURITY DEFINER RPCs, tables with RLS enabled but no policies, and disabled leaked-password protection. These findings require a routine-by-routine and table-by-table permission review; they must not be “fixed” by indiscriminately granting access or removing RLS. The current profile read policy is owner-scoped (`id = auth.uid()`).

The application must be revalidated after this patch on a physical Android device. A successful CI build is necessary but not sufficient for release acceptance.

## Final status

| Phase | Software foundation | Operational completion |
|---|---|---|
| 1. Evidence and code audit | Branding/auth-path corrections and CI checks in this patch; previous audit complete | Awaiting this patch's CI result and real-device validation |
| 2. GIS and conflict detection | PostGIS schema and advisory logic present | Blocked by 0 authorised underground assets/evidence |
| 3. Permits and coordination | Workflow/RPC foundations present | Blocked by 0 live permits/restoration/inspection records and authority validation |
| 4. Field verification | Upload and inspection foundations present | Blocked by field capture, authorised evidence and device verification |
| 5. Controlled pilot | Pilot protocol and KPIs specified | Not run; no authorised cohort or measured baseline |
| 6. Integration and expansion | National directory/catalogue metadata present | Blocked by 0 admin-unit rows, data agreements and tested integrations |

**Conclusion:** the source-side fixes in Phase 1 can be committed and tested here. Phases 2–6 cannot truthfully be marked 100% complete until official asset owners, municipal authorities, field teams, integration credentials and a measured pilot are available. No synthetic utility geometry, fake approval, false field evidence or unmeasured savings has been introduced by this execution.
