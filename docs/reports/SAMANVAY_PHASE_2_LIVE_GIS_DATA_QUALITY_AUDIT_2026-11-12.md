# SAMANVAY Phase 2 — live national GIS data-quality audit

**Audit date:** 12 November 2026  
**Database:** Connected SAMANVAY Supabase project  
**Purpose:** Separate imported reference coverage from authority-verified GIS and operational utility geometry.

## Executive result

The national administrative directory has broad reference coverage, but the imported LGD/API mirror records are not authority-verified. District reference polygons are topologically valid in the current table but are older, code-less datasets from mixed 2011–2019 vintages. Groundwater station observations are substantial and internally consistent at the source-record level, but their observation dates stop at 31 December 2025. Building-footprint catalog entries are not imported as operational footprints. The underground asset and survey-evidence registries remain empty.

No result in this audit establishes that an area is clear for excavation.

## National administrative directory

Current active LGD-code-bearing reference records in `public.india_administrative_units`:

| Unit type | Distinct LGD codes | Source vintage | Verification |
|---|---:|---|---|
| District | 784 | India LGD Community Mirror, 21 Oct 2026 | Imported, unverified |
| Sub-district | 7,092 | India LGD Community Mirror, 21 Oct 2026 | Imported, unverified |
| Block | 7,312 | India LGD Community Mirror, 21 Oct 2026 | Imported, unverified |
| Urban local body | 5,050 | India Cities & Administrative Data API mirror, 23 Sep 2026 | Imported, unverified |

The ULB directory is therefore present; it is not yet an authoritative boundary layer. The counts above are distinct non-null LGD codes after filtering active records. They are not counts of current verified administrative units, and the community mirrors must not be labelled as official government certification.

### Import-batch reconciliation

The live `public.india_directory_import_batches` ledger currently reports:
- Districts: 784 community-mirror rows imported; separate authorised-export tasks remain queued for all 36 State/UTs.
- Sub-districts: 7,092 imported from the 21 Oct 2026 community mirror.
- Blocks: 7,342 source rows received; 7,312 inserted; 30 rejected because 15 LGD block codes appeared under two different district parents. Both sides of each conflicting code were rejected rather than arbitrarily selecting one parent.
- Urban local bodies: 5,050 imported from the 23 Sep 2026 community/API mirror, with no district-parent fields supplied by the source; 36 authorised-export tasks remain queued for official LGD reconciliation.
- District name/reference imports from older DataMeet sources remain separate, code-less and non-authoritative.

A completed mirror import does not close the separate authorised-export task. The 36 queued district tasks and 36 queued ULB tasks remain open until an official LGD export is supplied, validated and imported.

### District boundary reference geometry

The separate `public.india_district_boundary_reference` table contains 733 district-name geometries across 37 state/UT labels. The live QA query found:
- 733 distinct state/district name pairs;
- 0 invalid geometries;
- 0 geometries outside SRID 4326;
- mixed source vintages from 2011 through 2019.

These are code-less DataMeet-derived reference geometries. Valid geometry does not make the boundaries current or authoritative. They must not be joined to LGD records solely by approximate name matching or used to imply the current district shape where post-2019 changes occurred.

### GSI / NWIC administrative boundary reference catalogue

Three additional GSI/NWIC resources were registered in `public.official_data_sources` by migration `20261112103650_register_nwic_state_subdistrict_and_village_boundaries`:

| Reference layer | Portal-reported source date | Published detail | SAMANVAY status |
|---|---|---|---|
| State / UT boundaries | 1 May 2025 | GeoJSON resource; open licence label, terms unspecified | Metadata registered; no geometry imported |
| Sub-district boundaries | 5 May 2025 | 6,312 reference features; open licence label, terms unspecified | Metadata registered; no geometry imported |
| Village boundaries | 2 May 2025 for the Tamil Nadu resource | State/UT-wise KML/GeoJSON/Shapefile catalogue | Metadata registered; coverage and completeness not yet confirmed |

Official catalogue pages:
- State boundaries: https://nwdp.nwic.gov.in/en/dataset/state-boundary/resource/f039e721-132c-4a24-9e5e-07af03064b4d
- Sub-district boundaries: https://nwdp.nwic.gov.in/en/dataset/sub-district-boundary
- Village boundaries: https://nwdp.nwic.gov.in/dataset/village-boundary
- Tamil Nadu village KML metadata: https://nwdp.nwic.gov.in/dataset/village-boundary/resource/2d9c31ea-02d0-4424-b76b-5b531cb569f6

The NWIC sub-district feature count (6,312) differs from the 7,092 LGD-code-bearing community-mirror rows. This is a reconciliation warning, not a reason to drop or remap either source. The layers remain separate until stable identifiers, effective dates, CRS, topology and licence terms are verified. A direct attempt to retrieve the district GeoJSON ZIP did not complete in this execution environment; no claim is made that the NWIC geometry has been downloaded, validated or imported. The existing 733 DataMeet district geometries remain the only persisted district polygon reference layer and remain historical, code-less and non-statutory.

### Survey of India administrative boundary source candidate

Survey of India lists its Administrative Boundary Database as SHAPEFILE products at scale 1:1M. Product `OVSF/1M/6` covers the entire country up to taluk/sub-district level with headquarters; `OVSF/1M/7` covers the entire country up to district level with headquarters. Both are listed at ₹0 on the product catalogue. The Survey of India portal describes these products as state, district and sub-district administrative boundaries.

**Access-route clarification (12 November 2026):** the product-catalogue route previously tested opened a sign-in prompt. However, the Survey of India FAQ separately states that the Administrative Boundary Database is available through the homepage's **Quick Access** route without registration or login. The portal catalogue lists the all-India `OVSF/1M/6` (up to taluk/sub-district) and `OVSF/1M/7` (up to district) shapefiles at ₹0. The Quick Access download workflow has not yet been exercised in this session and no archive has been retrieved, so no download, hash, CRS, topology or import is claimed.

Sources:
- Survey of India FAQ (Q7, Quick Access no-login workflow): https://onlinemaps.surveyofindia.gov.in/FAQs.aspx
- Survey of India home page (Quick Access section): https://onlinemaps.surveyofindia.gov.in/Home.aspx
- Survey of India product catalogue: https://onlinemaps.surveyofindia.gov.in/Digital_Products.aspx
- Survey of India product description: https://onlinemaps.surveyofindia.gov.in/AboutPortal.aspx

Next action: use the published Quick Access route for the free administrative-boundary archive, then retain its exact filename and SHA-256, inspect source date and attribute fields, validate CRS/geometry/topology and reconcile source codes to LGD before importing. If the Quick Access button does not deliver the file, report the observed error to Survey of India support; do not infer that the FAQ's published no-login route is unavailable from the separate catalogue sign-in prompt. Do not relabel the existing 733 DataMeet polygons as current official geometry in the meantime.

## Groundwater observations

The raw `public.groundwater_station_observations` table contains 446,068 records across 35 source resource IDs.

| QA measure | Live result |
|---|---:|
| Records with latitude and longitude | 445,553 |
| Records missing one or both coordinates | 515 |
| Invalid latitude/longitude ranges | 0 |
| Missing observation timestamps | 0 |
| Unique (source resource, source record) pairs | 446,068 |
| Earliest observation | 1 Jan 2025 |
| Latest observation | 31 Dec 2025, 18:00 local timestamp |

There are no duplicate source-record pairs in this snapshot. The 515 coordinate-incomplete records should remain non-spatial; do not derive or invent coordinates.

The separate `public.groundwater_district_assessments` register contains 225 district assessment rows for assessment year 2025 across 8 states. Its validation statuses are:
- 26 `aggregate_reconciled`;
- 199 `row_crosschecked_not_aggregated`.

This assessment table is not nationwide coverage. The UI must show its eight-state coverage and the 2025 assessment vintage rather than presenting it as a live all-India groundwater status. The station observation dataset also ends in 2025 and should be described as historical/latest-imported observations, not live telemetry.

## Building footprints and 3D map data

The `gis.building_footprint_source_registry` contains catalogue metadata, not imported building features:

| Source | Current status | Imported features | Operational use |
|---|---|---:|---|
| Google Open Buildings v3 | Catalogued, not imported | 0 | No |
| Microsoft Global ML Building Footprints | Catalogued, not imported | 0 | No |
| OpenBuildingMap global | Catalogued, not imported | 0 | No |
| OpenFreeMap / OpenStreetMap vector tiles | Live map-tile source | 0 imported records | Yes, render-only |
| Survey of India building sectoral layers | Catalogued, not imported; coverage pending | 0 | No |

The current source register does not substantiate a national imported building-footprint dataset. Do not describe the 3D map as a national verified building model until licensed/authorised geometry is obtained and imported with source attribution and QA. Render-only vector tiles must remain distinguished from SAMANVAY-owned feature records.

## Underground utility data

Live table counts:
- `gis.underground_assets`: 0;
- `gis.asset_survey_evidence`: 0;
- `public.utility_geometry_import_runs`: 0.

Therefore no utility-owner geometry or field-survey evidence has been imported into the current project database. The app must keep underground coverage explicitly marked unavailable/unverified. A blank underground layer must never be worded as “no utilities”, “safe”, or “clear to dig”.

## Phase 2 execution priorities

1. **Authoritative administration:** Obtain the official LGD bulk export through the authorised access process, validate it, and reconcile community-mirror records. Do not bypass CAPTCHA or access controls.
2. **ULB and ward boundaries:** Source current government/local-body polygons with licence and effective date. The 5,050 ULB registry rows are names/codes, not 5,050 operational ward boundary layers.
3. **Current district geometries:** Obtain the Survey of India `OVSF/1M/6` or `OVSF/1M/7` shapefile through an authorised download route; the free product currently prompts for login. Validate the file's source date, code fields, geometry and use terms before importing, and retain the older DataMeet reference only as a visibly dated fallback.
4. **Building geometry:** Obtain and licence an India-wide building-footprint source; import features with per-source lineage, geometry validity checks and known height provenance before enabling evidence-backed 3D extrusion.
5. **Utility-owner data:** Request authorised water, sewer, drainage, power, telecom and gas as-built/field-survey geometry. Preserve owner restrictions and require survey evidence before marking geometry verified.
6. **Groundwater freshness:** Refresh the official source feeds and keep the 2025 observation dataset labelled with its date range and 8-state assessment coverage.
7. **Device acceptance:** Validate satellite tiles, GIS layer navigation and any extruded buildings on representative Android devices and browser viewport sizes once source-backed layers are available.

## Completion state

Phase 2 is **not complete**. The administrative count correction, national reference imports, dated district reference QA and groundwater source register are in place. Official directory verification, current ULB/ward/district polygons, imported building footprints, owner-authorised utility geometry, fresh groundwater observations and on-device GIS acceptance testing remain outstanding.

## Database security hardening and verification-queue access — 12 November 2026

Two migrations were applied to the connected Supabase project and aligned to their applied version identifiers in the repository:

- `20261112105020_harden_utility_verification_access`
- `20261112105144_harden_highway_notice_rpc_search_path`

The verification queue view, `public.utility_asset_verification_queue`, now has both `security_barrier=true` and `security_invoker=true`. The view's base tables remain protected by RLS. Authenticated SELECT is granted only where needed for the view, and the GIS assets, survey evidence and utility import-run rows are filtered to profiles whose role is `admin` or `coordinator`. There are no client INSERT/UPDATE/DELETE grants on the two GIS source tables.

The internal `ai_chat_usage_events`, `groundwater_data_import_runs` and `utility_asset_review_events` tables now have explicit deny-all RLS policies for `anon` and `authenticated`; privileged server ingestion remains separate.

The authenticated security-definer RPC audit confirmed that the 15 app-facing functions are not executable by `anon`. They remain executable by `authenticated` because the Flutter workflows call them and the functions contain role/ownership checks. The one app-facing function found with a non-empty search path, `publish_highway_work_notice`, now has an empty search path; its application tables and `auth.uid()` are already schema-qualified. The 15 remaining security-definer function lint notices are therefore tracked as intentional privileged RPC endpoints, not treated as proof that the app is secure.

### Live verification after migration

- Verification queue view options: `security_barrier=true`, `security_invoker=true`.
- Previously policy-less tables: 6/6 now have explicit RLS policies.
- Security-definer view linter finding: cleared.
- RLS-enabled/no-policy linter findings: cleared.
- Anonymous execution for the 15 app-facing security-definer functions: false.
- Remaining Auth configuration warning: leaked-password protection disabled; it requires the Supabase Auth project setting and was not changed through SQL.
- Test limitation: the underground-asset and survey-evidence tables currently contain zero records. Admin and Citizen SQL sessions both returned zero verification-queue rows, which verifies query execution but is not a meaningful non-empty positive/negative data-access test. Full role regression must be repeated after owner-authorised test records exist.

This hardening reduces the view-owner privilege boundary and makes internal logs explicitly server-managed. It does not replace external security review, field/device QA or utility-owner data validation.

### Authenticated role smoke tests (12 November 2026)

All tests ran as the `authenticated` database role with controlled JWT subject claims inside transactions that were rolled back:

| Session | Test | Result |
|---|---|---|
| Citizen | `admin_create_department` | Denied |
| Citizen | `admin_user_directory` | Denied |
| Citizen | `assign_request_department` | Denied |
| Citizen | `get_map_utility_conflict_advisories` | Denied |
| Citizen | `get_my_department_verified_assets_geojson` | Denied |
| Citizen | `submit_department_review` | Denied |
| Admin | `admin_user_directory` | Allowed; 6 profiles returned |
| Coordinator | empty-list utility advisory | Allowed; no results, no geometry disclosure |
| Department Officer | owner-scoped GeoJSON endpoint | Allowed; empty FeatureCollection |
| Citizen | generalised 250 m GIS overview | Allowed; empty FeatureCollection |

The six Citizen negative checks passed; the positive calls returned the expected role-specific shape. No write operation succeeded and no test data was retained. Because `gis.underground_assets` and `gis.asset_survey_evidence` still contain zero rows, these are function/role-gate smoke tests, not a positive-data row-visibility test and not a production penetration test.

## 21. National GIS default and local reference-layer isolation — 12 November 2026

- [x] Default GIS camera opens over India (fallback centre 22.5° N, 79.0° E) when no local map context is supplied.
- [x] Keep the national region presets for All India, North, Northeast, East, Central, West, South, Andaman and Nicobar, and Lakshadweep.
- [x] Change the Coimbatore 2024 ward reference layer to opt-in, not auto-loaded. Its label explicitly says it is Coimbatore-only and is neither national nor statutory coverage.
- [x] Preserve the ward reference data and user-controlled toggle; the change only prevents it from appearing by default.
- [ ] Validate camera navigation, map layers and the ward toggle on Android and browser after CI completes.

**Implementation:** `app/main.dart` commit `21a0ee5d2570e1e337ad34c54d8824f86e26e748`. The Android and browser workflow runs for this commit are in progress; Dart analysis passed in both workflows before release compilation.

### Survey of India Quick Access route re-check

The official Survey of India FAQ says that the Administrative Boundary Database can be downloaded from the homepage's Quick Access section without registration or login. It instructs users to choose the dataset category, select the required map and click Download. This supersedes the earlier assumption that the product itself necessarily requires login: only the separate product-catalogue route was observed to prompt for sign-in. The Quick Access route remains untested in this session, and no shapefile archive has been obtained or imported.

### Positive/negative row-level access test using rollback-only fixture

A synthetic import-run row, verified-asset row and evidence row were inserted inside a single SQL transaction, then queried under four authenticated JWT identities. The transaction was explicitly rolled back after returning the results.

| Role | Underground asset | Survey evidence | Import run | Verification queue |
|---|---:|---:|---:|---:|
| Admin | 1 | 1 | 1 | 1 |
| Coordinator | 1 | 1 | 1 | 1 |
| Department Officer | 0 | 0 | 0 | 0 |
| Citizen | 0 | 0 | 0 | 0 |

**Result:** all four role expectations passed. The Department Officer was intentionally excluded from the admin/coordinator review queue even though the synthetic row was owned by that officer's department; the owner-only exact-geometry workflow remains separately handled by the dedicated RPC. The synthetic asset/evidence/import rows were rolled back and are not present in production data. This test validates actual row-level filtering and view execution without retaining synthetic data; it does not replace tests with real owner-authorised records.
