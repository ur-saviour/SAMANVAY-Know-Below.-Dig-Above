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

### District boundary reference geometry

The separate `public.india_district_boundary_reference` table contains 733 district-name geometries across 37 state/UT labels. The live QA query found:
- 733 distinct state/district name pairs;
- 0 invalid geometries;
- 0 geometries outside SRID 4326;
- mixed source vintages from 2011 through 2019.

These are code-less DataMeet-derived reference geometries. Valid geometry does not make the boundaries current or authoritative. They must not be joined to LGD records solely by approximate name matching or used to imply the current district shape where post-2019 changes occurred.

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
3. **Current district geometries:** Acquire current code-linked district boundaries and retain the older DataMeet reference only as a visibly dated fallback.
4. **Building geometry:** Obtain and licence an India-wide building-footprint source; import features with per-source lineage, geometry validity checks and known height provenance before enabling evidence-backed 3D extrusion.
5. **Utility-owner data:** Request authorised water, sewer, drainage, power, telecom and gas as-built/field-survey geometry. Preserve owner restrictions and require survey evidence before marking geometry verified.
6. **Groundwater freshness:** Refresh the official source feeds and keep the 2025 observation dataset labelled with its date range and 8-state assessment coverage.
7. **Device acceptance:** Validate satellite tiles, GIS layer navigation and any extruded buildings on representative Android devices and browser viewport sizes once source-backed layers are available.

## Completion state

Phase 2 is **not complete**. The administrative count correction, national reference imports, dated district reference QA and groundwater source register are in place. Official directory verification, current ULB/ward/district polygons, imported building footprints, owner-authorised utility geometry, fresh groundwater observations and on-device GIS acceptance testing remain outstanding.
