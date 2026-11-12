# SAMANVAY — Phase 1 and Phase 2 verification addendum

**Audit date:** 12 November 2026  
**Repository branch:** `feature/alpha-03-integrated-platform`  
**Latest branch head at writing:** `d1a1978d6c1f51ea880c1f075ca424f01efceb30`  
**Application commit used for the passing builds:** `04e18f3aa9e5ab06eac56c94f083c54f6b8c3c48`  
**Supabase project:** `zhtotivedvkmclerdnlf`

This addendum records work completed after the six-phase report. It separates repeatable software/database tests from device acceptance and from data that must be supplied by external authorities. It does not claim 100% operational completion.

## Phase 1 — Core platform, authentication and role controls

### Completed and verified

- Confirmed six Auth users and six linked profile rows: three Citizen (`requester`) accounts, one Department Officer (`department`), one Coordinator and one Administrator. All six have confirmed email addresses; the Department Officer profile has a department assignment.
- Corrected the invalid-password message so it no longer instructs users to use Email OTP when Email OTP is disabled for this project. The change is committed in `app/main.dart` at application commit `04e18f3`.
- Verified that role labels in the visible app UI use **Citizen**; the internal database value `requester` remains as a role key.
- Ran authenticated-role database checks for one account of each role. Each role could read its own profile row; each could read the 36-row State/UT directory, all 396 coverage metadata rows, and the 576-row latest-groundwater-station view. The admin/coordinator verification-metadata view returned no rows because the asset registry is empty. Direct access to restricted GIS asset tables remained denied.
- Ran the generalised utility overview RPC under all four roles. It returned a valid FeatureCollection with zero features for each role, matching the empty verified-asset registry.
- Ran the staff conflict-advisory RPC as Administrator and Coordinator. Both calls were authorised and correctly reported `verified_assets_available=false`; the three existing requests lacked work-site locations. Citizen access was rejected. The Department Officer call was rejected for the supplied requests because they were not assigned to that account.
- Ran the Department Officer's owner-scoped verified-asset GeoJSON RPC. It returned a valid FeatureCollection with zero features and the expected owner-department scope.
- Android build workflow passed: Flutter dependency installation, Dart analysis, release APK build, package/signature/alignment checks and artifact upload.
- Browser workflow passed: Dart analysis, browser compilation, GIS asset smoke test and artifact packaging.

### Build records

- Android workflow: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43176627680
- Browser workflow: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43176627935
- App commit: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/commit/04e18f3aa9e5ab06eac56c94f083c54f6b8c3c48
- APK artifact: `SAMANVAY-Alpha-0.3-APK`, artifact ID `13924771742`, 44,276,707 bytes. GitHub reported SHA-256 `cb65b650b4641636112bb10dca289c0d4a5ba30616a71c16d03ba6f452cacc0b`.

The most recent repository commits after the passing build add only SQL source-catalogue migrations; they do not change the Flutter application source.

### Still required for 100%

- A human must test the actual existing account credentials on physical Android devices. Credentials were not available for controlled sign-in tests in this audit.
- Test password recovery, email confirmation, role landing pages, logout/session expiry and account switching against real Supabase Auth sessions.
- Test GPS permission, map tile delivery, satellite mode, file/photo upload and all major role journeys on supported devices.
- Review Supabase Auth leaked-password protection and all SECURITY DEFINER advisories. Six RLS-enabled tables with no policies have no direct authenticated grants; that restriction is intentional and must not be removed to clear a lint warning. The SECURITY DEFINER RPCs have role checks and empty search paths; any ACL changes must be reviewed function by function.

**Assessment:** The source-level fixes and CI verification are complete. Real-device and credentialed acceptance remains open. Phase 1 is not 100% operationally complete.

## Phase 2 — GIS, administrative reference and utility conflict screening

The detailed, superseding data/import record is [SAMANVAY Phase 2 National GIS Data Import and Verification Report — 12 November 2026](SAMANVAY_PHASE_2_NATIONAL_REFERENCE_IMPORT_2026-11-12.md).

### Updated live administrative data

A pinned community mirror of Ministry of Panchayati Raj LGD data (snapshot date 21 October 2026; mirror commit `0f79118dc9cf574bed90025163a3d0653386d6e2`) was imported into Supabase:

| Entity | Received | Inserted | Rejected |
|---|---:|---:|---:|
| Districts | 784 | 784 | 0 |
| Sub-districts | 7,092 | 7,092 | 0 |
| Blocks | 7,342 | 7,312 | 30 |
| **Total** | **15,218** | **15,188** | **30** |

All inserted rows retain LGD codes, parent links, source date and provenance, and remain `imported_unverified`. Thirty block records representing 15 duplicated codes were rejected. The snapshot is from a community mirror, not a live Ministry connection; it was 22 days old on the audit date and outside its documented 14-day freshness target. It contains no ULB, ward, village or gram-panchayat hierarchy.

### Other persisted reference data

- The pre-existing DataMeet national district directory contains 734 district-name records without LGD codes.
- `public.india_district_boundary_reference` contains 733 generalized WGS84 district polygons, all valid and linked to 733 administrative-unit rows. Source feature vintages vary from 2011_c to 2019/update2014; this is not survey-grade or statutory boundary data.
- A parallel state-wise DataMeet source was imported as 733 separate district-name rows for cross-checking; 728 match the national DataMeet names, 5 are state-wise-only and 6 are national-file-only.
- The public geoBoundaries Edge Function continues to fetch ADM1/ADM2 reference data on demand; the Flutter app does not directly query the persisted DataMeet polygon table.
- Groundwater observations remain 446,068 historical source rows (445,553 geocoded), with 576 latest-per-station map rows (574 geocoded). These are groundwater monitoring observations, not utility alignments.

### Utility and operational status

- `gis.underground_assets`: 0 rows.
- `gis.asset_survey_evidence`: 0 rows.
- Restricted utility-source registry: 11 entries; 0 operational approvals.
- Utility conflict-advisory software exists, but the empty verified-asset registry means **data unavailable** and cannot support a “no conflict” or excavation-clearance conclusion.
- Field survey, owner verification, current ULB/ward hierarchy, physical-device map acceptance and independent conflict-test cases remain open.

**Assessment:** National district/sub-district/block reference data is now populated from a dated community mirror and public district-boundary references are persisted. Phase 2 is still not 100% operationally complete because ULB/ward/village coverage, fresh authority verification, owner-authorised underground geometry, field evidence and device/pilot acceptance remain outstanding.

## Overall closure assessment

| Phase | Engineering status | Operational status |
|---|---|---|
| 1. Core platform and authentication | Source fix committed; Android and browser CI passed; role/RLS behaviour tested in database contexts | Physical-device and credentialed account tests remain |
| 2. GIS and conflict detection | 784 districts, 7,092 sub-districts, 7,312 blocks, 733 generalized district polygons, groundwater reference and role-restricted GIS code | 0 verified utility geometries, 0 survey evidence; ULB/ward/village hierarchy, authoritative refresh, field and device validation remain |

**Important:** 100% completion cannot be claimed until the external data owners provide permitted utility datasets and the remaining device/field acceptance tests are performed. A successful build and a populated source catalogue are not substitutes for those dependencies.
