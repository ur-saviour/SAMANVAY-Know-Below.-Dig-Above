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

### Live database snapshot

| Dataset | Live result | Meaning |
|---|---:|---|
| Groundwater station observations | 446,068 | Historical source observations in the raw station table |
| Groundwater observations with coordinates | 445,553 | 515 source rows are not geocoded |
| State/UT labels represented in station data | 31 | Not uniform 36/36 station coverage |
| Latest observation date | 31 Dec 2025 | Historical observations, not a live telemetry feed |
| Latest-per-station map view | 576 | One latest record per station (view rows) |
| Latest-per-station rows with coordinates | 574 | Two latest-station records lack coordinates |
| State/UT master directory | 36 | All States/UTs represented |
| India coverage metadata | 396 | 36 jurisdictions × 11 domains |
| India administrative-unit hierarchy | 0 | No imported district/ULB/ward LGD rows |
| LGD district batches awaiting authorised export | 36 | Export pending |
| LGD ULB batches awaiting authorised export | 36 | Export pending |
| GIS underground assets | 0 | No verified underground asset geometries |
| GIS asset survey evidence | 0 | No survey evidence records |

The raw observation table and latest-station map view are different datasets: 446,068 is not the number of map markers. Groundwater monitoring observations are not water-pipeline geometry.

### Utility-source discovery snapshot

- Restricted utility source registry: 11 records.
- Aggregate feature counts stated by those source records: 658,896.
- Operationally approved source records: 0.
- Source records marked not imported: 11.
- Utility layer catalogue: 125 records.
- Operationally approved layer-catalogue records: 0.
- `gis.underground_assets`: 0 rows.
- `gis.asset_survey_evidence`: 0 rows.

The 658,896 value is the sum of source-catalogue feature-count metadata, not a count of features imported into SAMANVAY. The source registry explicitly records authority review as required and `operational_use_allowed=false`. Publicly queryable service metadata does not establish data-sharing rights, survey accuracy, source freshness or permission to copy and operate on detailed utility geometry.

### GIS tests

- `get_underground_asset_overview` returned a valid, empty FeatureCollection under Citizen, Department Officer, Coordinator and Administrator contexts. This is consistent with zero verified assets and must display as data unavailable, not as evidence that no utilities exist.
- `get_map_utility_conflict_advisories` authorised Administrator and Coordinator calls. The test requests lacked work-site coordinates and the function stated that verified assets were unavailable. Citizen access was rejected. Department access was rejected for those particular unassigned requests.
- `get_my_department_verified_assets_geojson` returned an empty, department-scoped FeatureCollection. No exact asset geometry was disclosed.
- The national reference-boundary Edge Function is deployed and active with JWT verification. It proxies geoBoundaries India ADM1/ADM2 reference data; this is a public map reference, not an LGD-code-verified statutory directory.

### Additional source-catalogue work completed

Three government reference entries have been added to `public.official_data_sources` and recorded in repository migrations:

1. **GSI / NWIC India District Boundary:** NWIC describes a 733-district reference layer, identifies the Geological Survey of India as producer, and reports a dataset update of 5 May 2025. The resource page lists GeoJSON, KML and Shapefile downloads: https://nwdp.nwic.gov.in/dataset/district-boundary
2. **OGD LGD Districts:** the Government of India OGD catalogue lists the LGD district resource, with monthly refresh metadata updated 27 October 2026: https://data.gov.in/resource/local-government-directory-lgd-districts
3. **OGD LGD Local Bodies:** the OGD catalogue lists the LGD local-body resource, with monthly refresh metadata updated 28 October 2026: https://data.gov.in/resource/local-government-directory-lgd-local-bodies

These entries are intentionally marked `metadata_registered`, not `imported`. The NWIC ZIP download was not successfully retrieved in this execution environment. The OGD resource API payloads were not downloaded or validated. No CAPTCHA or access control was bypassed, and no district/ULB records were fabricated.

Repository migrations:
- `supabase/migrations/20261112082821_register_nwic_india_district_boundary_reference.sql`
- `supabase/migrations/20261112100000_register_lgd_ogd_resource_metadata.sql`

Both migrations were applied to the connected Supabase project and verified in the migration ledger.

### Still required for 100%

- Retrieve the NWIC district boundary package and perform file checksum, schema, CRS, geometry-validity, feature-count and source-date checks before considering it for public reference display.
- Retrieve the current LGD district and local-body records through an authorised OGD/LGD download or API route; reconcile by LGD code and import with provenance and batch audit.
- Obtain authority-approved underground utility data for water, sewer, stormwater, electricity, gas and telecom. Each dataset needs documented custodian permission, source date, CRS, accuracy, vertical datum/depth metadata, licence/data-sharing basis and secure delivery.
- Receive survey evidence and owner verification before enabling operational conflict screening. Do not infer utility routes from surface maps, groundwater wells, building footprints or catalogue counts.
- Complete on-device map regression tests and validate the map boundary Edge Function response from a real authenticated app session.
- Implement true subsurface 3D only after validated geometry, depth, vertical datum and accuracy evidence are supplied. Current 3D map styling is not a field-verified volumetric utility model.

**Assessment:** The national GIS reference and role-protected software foundations exist. Operational utility GIS and the nationwide LGD hierarchy remain unpopulated. Phase 2 is not 100% complete.

## Overall closure assessment

| Phase | Engineering status | Operational status |
|---|---|---|
| 1. Core platform and authentication | Source fix committed; Android and browser CI passed; role/RLS behaviour tested in database contexts | Physical-device and credentialed account tests remain |
| 2. GIS and conflict detection | National map, source registry, PostGIS/RPC and role restrictions present; three additional national reference-source entries registered | 0 verified utility geometries, 0 survey evidence, 0 LGD administrative units; authority data imports and field validation remain |

**Important:** 100% completion cannot be claimed until the external data owners provide permitted utility datasets and the remaining device/field acceptance tests are performed. A successful build and a populated source catalogue are not substitutes for those dependencies.
