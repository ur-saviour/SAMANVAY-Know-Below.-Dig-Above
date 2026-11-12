# SAMANVAY — Phase 2 national GIS data import and verification report

**Status snapshot:** 12 November 2026  
**Repository branch:** `feature/alpha-03-integrated-platform`  
**Supabase project:** `zhtotivedvkmclerdnlf`  
**Latest navigator change:** `d1a5f72b304fb64679524623cc8b8b7e0ef131d5`

This report supersedes earlier Phase 2 counts and statements in the same-day execution notes. It separates three kinds of evidence: imported administrative records, generalized public reference geometry, and owner-authorised utility data. These are not interchangeable.

## 1. New India-wide LGD hierarchy snapshot imported

A public community mirror of Ministry of Panchayati Raj Local Government Directory (LGD) data was found and pinned to a reproducible Git commit:

- Mirror/API project: https://github.com/shrinivas-sn/india-lgd-index-api
- Pinned commit: `0f79118dc9cf574bed90025163a3d0653386d6e2`
- Pinned data folder: https://github.com/shrinivas-sn/india-lgd-index-api/tree/0f79118dc9cf574bed90025163a3d0653386d6e2/backend/data
- Source mirror: https://github.com/ramSeraph/opendata
- Authoritative directory named by the mirror: https://lgdirectory.gov.in/
- Licence attribution in the mirror metadata: Government Open Data License — India (GODL-India)

The pinned `meta.json` reports **source_date = 21Oct2026**, `ingested_at = 2026-10-29T17:11:49.883Z`, and these row counts: 36 States/UTs, 784 districts, 7,092 sub-districts and 7,342 blocks. The mirror repository states that it is an independent community project and is not affiliated with the Ministry. It describes a weekly refresh process, but the pinned snapshot is 22 days old on 12 November 2026 and is therefore beyond its documented 14-day freshness target. This is a secondary mirror of LGD data, not a live Ministry connection or authority confirmation.

### Import result in the live Supabase database

| Entity level | Source rows received | Rows inserted | Rows rejected | Parent validation |
|---|---:|---:|---:|---|
| District | 784 | 784 | 0 | 36/36 State/UT parents matched |
| Sub-district | 7,092 | 7,092 | 0 | All parent district codes matched; no state mismatch |
| Block | 7,342 | 7,312 | 30 | All imported records linked to a matching parent district |
| **Total** | **15,218** | **15,188** | **30** | **0 missing parent links in imported rows** |

All 15,188 imported rows have:
- their LGD code copied from the mirror field without inventing a code;
- a source-specific `source_system` value;
- the 21 October 2026 source date and pinned source URL;
- state code and source-state label provenance;
- `verification_status = 'imported_unverified'`.

The 30 rejected block rows belong to 15 codes that each appeared twice under different districts in the mirror. Both records for each duplicated code were rejected. No arbitrary duplicate winner was selected. The affected codes are recorded in the import-batch notes and were not inserted as active block records.

The source uses overlapping numeric code values across entity levels. To preserve the existing unique `(source_system, lgd_code)` constraint without conflating districts, sub-districts and blocks, each level is stored under a distinct source namespace.

### Live import-batch IDs

| Entity level | Batch ID | Status |
|---|---|---|
| District | `0695a02d-61ef-4230-a9de-b36edcea677b` | imported |
| Sub-district | `27724025-4fc8-420e-9f53-159101e30303` | imported |
| Block | `87fc6c0c-27d4-421f-957d-5b3dc1952c97` | imported (30 duplicate-code rows rejected) |

Sub-district and block source rows contain a district code, not a sub-district parent code. Therefore the imported `parent_unit_id` for both levels points to the matching district. This is the strongest hierarchy the supplied mirror schema supports; the report does not claim a finer block-to-sub-district link.

The snapshot does **not** contain urban local bodies, wards, villages or local-body boundary polygons. Those levels are still missing from the national hierarchy import.

## 2. Older district-name reference sets retained separately

The database also contains two historical/community district-name collections. They are intentionally not merged into the 2026 mirror because their coverage and names differ.

### Existing national DataMeet directory and polygons

The pre-existing national DataMeet collection contains:
- 734 district-name rows in `public.india_administrative_units`;
- 733 linked records in `public.india_district_boundary_reference`;
- 733 valid WGS84 geometries (SRID 4326), with no invalid or empty polygons;
- 36 current parent State/UT IDs, while the source has 37 raw historical jurisdiction labels.

Every persisted polygon is marked generalized in its source attributes. Its source notes specify Douglas–Peucker simplification of shared TopoJSON arcs at 0.0015 degrees. These are generalized administrative reference polygons, not survey-grade boundaries, not underground asset geometry, and not a legal confirmation of current administrative limits.

The source feature-year distribution is mixed:
- 2011_c: 629
- 2012_c: 1
- 2014_c: 2
- 2015_c: 6
- 2016_c: 41
- 2017_c: 3
- 2018: 7
- 2019: 13
- update2014: 31

The pinned repository README says the DataMeet-derived collection is intended primarily for visualization, warns of naming issues, and notes that Saitual, Mizoram is absent. Its repository contains an MIT licence; that licence does not itself certify the underlying boundary provenance, current accuracy or statutory authority.

### Parallel state-wise DataMeet directory

A second pinned state-wise DataMeet collection was imported in this execution:
- 733 district-name rows received and inserted;
- all 36 parent State/UT mappings matched;
- 0 LGD codes assigned;
- all rows remain `imported_unverified`.

Comparison against the existing 734-row national collection found 728 exact State/UT + name matches, 5 state-wise-only names and 6 national-file-only names. It is retained as a separately versioned reference set and is not the preferred app fallback.

The app navigator now prefers the 21 October 2026 community LGD mirror when direct LGD rows are absent, and only then falls back to the older national DataMeet name reference. The 2019 collection is not used for permit approval or utility conflict clearance.

## 3. Public map boundaries and groundwater data

The application already has a JWT-protected `samanvay-public-boundaries` Edge Function that fetches geoBoundaries ADM1/ADM2 public reference GeoJSON on demand. This is a separate reference display path; it is not an LGD import. The Flutter application does not currently query the persisted 733-row DataMeet PostGIS polygon table directly.

The live groundwater source snapshot previously audited contains:
- `public.groundwater_station_observations`: 446,068 historical observations;
- 445,553 observations with coordinates and 515 without;
- 31 State/UT labels represented;
- latest source observation date: 31 December 2025;
- `public.latest_groundwater_station_observations`: 576 latest-per-station rows, 574 with coordinates.

The map's latest-per-station view is not the entire 446,068-row time series. These are groundwater monitoring observations; they are not water-pipeline alignments, sewer routes, gas lines, electrical cables or telecom ducts.

## 4. App behaviour updated

Latest app commit: `d1a5f72b304fb64679524623cc8b8b7e0ef131d5`.

The district navigator's fallback order is now:

1. Direct `Local Government Directory (LGD)` rows, when present.
2. `India LGD Community Mirror 21Oct2026 — Districts`, when direct LGD rows are absent.
3. The existing national DataMeet district-name reference, only when neither LGD source returns rows.

Community-mirror records are labelled as community LGD snapshot data, and the navigator warns that the snapshot is dated 21 October 2026, is not a live government feed, remains unverified and must not be used as permit, statutory or utility-clearance evidence. Older DataMeet names are labelled reference-only. The permit and conflict-check code paths were not switched to these fallback sources.

The Android and browser CI workflows for commit `d1a5f72` are:
- Android: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43190092973
- Browser: https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43190092969

CI completion is a software build check only. It does not replace physical-device acceptance.

## 5. Remaining Phase 2 blockers

| Workstream | Verified live state | What is still required |
|---|---|---|
| Current LGD district hierarchy | 784 districts with LGD codes from a community mirror snapshot | Refresh from an up-to-date authorised Ministry/LGD export; reconcile the mirror against the current source; authority verification |
| Sub-district hierarchy | 7,092 records with matching parent districts | Current refresh and authority validation |
| Development blocks | 7,312 inserted; 30 duplicate-code rows rejected | Resolve the 15 duplicate LGD codes against an authoritative export; refresh and validate |
| ULBs, panchayats, villages and wards | Not populated from this mirror | Current LGD local-body, village and ward records with parent codes |
| Administrative district polygons | 733 generalized third-party PostGIS reference polygons; separate geoBoundaries display path | Use a current approved official boundary source for statutory workflows; version and reconcile against LGD codes |
| Underground utility assets | 0 rows in `gis.underground_assets` | Utility-owner-authorised geometry, source date, licence/data-sharing permission, CRS, positional accuracy and depth metadata |
| Survey evidence | 0 rows in `gis.asset_survey_evidence` | Field capture, positional confidence, evidence, owner review and verification |
| Conflict detection | Software RPC exists; verified utility registry is empty | Authorised utility data and independently reviewed labelled test cases before operational use |
| Subsurface 3D | No verified utility geometry/depth model | Surveyed geometry, vertical datum, depth, accuracy and field validation |
| Physical-device GIS acceptance | CI pipelines compile the app | Real Android tests for map tiles, satellite mode, GPS, authenticated roles and map-layer behaviour |

The utility source catalogue previously audited contains 11 restricted source records with zero operational approvals. The sum of feature-count metadata in those source records is not a count of features imported into SAMANVAY. The underground asset table and asset survey-evidence table remain empty. An empty verified-asset registry means **data unavailable**, not that no underground utilities exist.

## 6. Reproducible verification SQL

```sql
-- Current 21Oct2026 mirror import batches
select id, unit_type, import_status, rows_received, rows_inserted,
       rows_rejected, source_updated_at, completed_at
from public.india_directory_import_batches
where id in (
  '0695a02d-61ef-4230-a9de-b36edcea677b',
  '27724025-4fc8-420e-9f53-159101e30303',
  '87fc6c0c-27d4-421f-957d-5b3dc1952c97'
)
order by unit_type;

-- Inserted hierarchy counts, code completeness and parent coverage
select source_system, unit_type,
       count(*) as rows,
       count(distinct state_ut_id) as state_ut_parents,
       count(distinct lgd_code) as distinct_lgd_codes,
       count(*) filter (where lgd_code is null) as rows_without_code,
       count(*) filter (where verification_status = 'imported_unverified') as unverified_rows
from public.india_administrative_units
where source_system like 'India LGD Community Mirror 21Oct2026%'
group by source_system, unit_type
order by unit_type;

-- Imported sub-districts and blocks with a missing parent (both should return zero)
select u.unit_type, count(*) filter (where p.id is null) as missing_parent_rows
from public.india_administrative_units u
left join public.india_administrative_units p on p.id = u.parent_unit_id
where u.source_system like 'India LGD Community Mirror 21Oct2026%'
  and u.unit_type in ('sub_district', 'block')
group by u.unit_type;
```

## 7. Phase 2 closure decision

**Completed in this execution:** imported a 2026 community-mirrored LGD hierarchy of 784 districts, 7,092 sub-districts and 7,312 unambiguous blocks; preserved LGD codes and source provenance; validated parent links; rejected all 30 records involved in duplicate block-code collisions; recorded source metadata and batch audit rows; updated the app navigator to prefer the newer mirror while visibly warning that it is unverified.

**Available reference foundation:** 733 generalized, valid WGS84 district polygons; 36 current State/UT parent records; 396 jurisdiction/domain coverage metadata rows; a geoBoundaries public boundary reference function; and the historical groundwater station dataset described above.

**Not complete:** an authoritative fresh LGD pull, national ULB/ward/village hierarchy, official current administrative polygons for statutory use, owner-authorised underground utility geometry, field survey evidence, independently validated conflict screening and physical-device acceptance.

Phase 2 is therefore **not 100% operationally complete**. The administrative reference data foundation has advanced substantially, but a software build and a populated public reference directory cannot substitute for underground asset evidence and authority validation. No synthetic utility routes, invented LGD codes, field evidence or false “no conflict” clearances have been created.
