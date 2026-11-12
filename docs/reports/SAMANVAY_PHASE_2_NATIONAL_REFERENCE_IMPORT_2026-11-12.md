# SAMANVAY — Phase 2 national reference-data import record

**Execution date:** 12 November 2026  
**Branch:** `feature/alpha-03-integrated-platform`  
**Supabase project:** `zhtotivedvkmclerdnlf`  
**Import batch:** `441de866-f89d-4505-bfbc-2d14ae9d81cc`  
**Application commit:** `93d3ae9f4c2aac5667609175c624afa05f31d5db`

## What was imported

A pinned Datameet-derived district-boundary reference repository was used to populate the administrative-name directory:

- Repository: https://github.com/guneetnarula/indian-district-boundaries
- Pinned commit: `d0347469bf845b96dd98fc61e80a28a8235190eb`
- State-wise directory: https://github.com/guneetnarula/indian-district-boundaries/tree/d0347469bf845b96dd98fc61e80a28a8235190eb/topojson/state-wise
- Repository README: https://github.com/guneetnarula/indian-district-boundaries/blob/d0347469bf845b96dd98fc61e80a28a8235190eb/README.md
- Repository licence file: https://github.com/guneetnarula/indian-district-boundaries/blob/d0347469bf845b96dd98fc61e80a28a8235190eb/LICENSE

The repository README describes the collection as a 2019 district reference for visualization, warns that some names need correction, and specifically notes that Saitual, Mizoram is absent. The repository contains an MIT licence; that licence does not independently certify the origin, accuracy, currency or operational rights for every underlying boundary dataset.

The state-wise TopoJSON files were parsed. Only district names and their parent State/UT names were inserted into `public.india_administrative_units`. Source Census-era codes, source year attributes and geometries were not copied into LGD fields or PostGIS.

### Live import result

| Check | Verified result |
|---|---:|
| State-wise input files processed | 36 |
| District attributes received | 733 |
| District records inserted | 733 |
| Rejected rows | 0 |
| Parent State/UT jurisdictions represented | 36 |
| Distinct State/UT + district-name pairs | 733 |
| Imported rows with an LGD code | 0 |
| Rows marked `imported_unverified` | 733 |
| Rows with an authority-verification claim | 0 |

The batch is marked `imported` because the file transfer and database insert completed. Each district row remains `imported_unverified`; batch status must not be interpreted as government validation.

The table uses this source label:

`Datameet India District Boundaries — 2019 reference (MIT-licensed repository)`

Each row is linked to its parent in `india_state_uts`, has `unit_type='district'`, has `lgd_code=NULL`, and carries the import batch ID above. No LGD identifiers have been inferred from Census-era source codes.

## Application change

Commit `93d3ae9f4c2aac5667609175c624afa05f31d5db` updates the jurisdiction navigator:

1. It first queries district rows from `Local Government Directory (LGD)`.
2. Only when no LGD district rows exist for a State/UT, it falls back to the 2019 Datameet reference names.
3. Reference entries are labelled `2019 reference only`.
4. The navigator displays a warning that these names are not current LGD records, have no LGD codes and must not be used as statutory or utility-clearance evidence.

The LGD importer, ULB and ward hierarchy, permit workflow and utility-conflict checks are not switched to this third-party fallback.

## Other Phase 2 data already present

These are distinct data products and must not be conflated:

- `public.groundwater_station_observations`: 446,068 historical observation rows; 445,553 have coordinates and 515 do not. Observation period in the audited source snapshot ends 31 December 2025.
- `public.latest_groundwater_station_observations`: 576 latest-per-station rows, of which 574 have coordinates. The map uses this latest-per-station view, not all 446,068 historical rows.
- State/UT master directory: 36 rows.
- India data-coverage metadata: 396 rows (36 jurisdictions × 11 data domains).
- The public boundary Edge Function proxies geoBoundaries ADM1/ADM2 reference GeoJSON on demand. This is a reference display layer and is not an LGD import or a utility network.

Groundwater observation points do not represent water-pipeline alignments, sewerage routes or other underground assets.

## Outstanding Phase 2 blockers

| Workstream | Live state | Required to close |
|---|---|---|
| Current statutory districts | Third-party 2019 names only; no LGD codes | Current LGD export/API records, code reconciliation and authority validation |
| Urban local bodies, blocks, wards and villages | No complete national hierarchy imported | Current LGD records and parent-code reconciliation |
| Official administrative polygons | Public geoBoundaries reference is fetched on demand; no validated national polygon set persisted to PostGIS | Source-vintage review, boundary QA, attribution and approved persistence strategy |
| Underground utility assets | 0 rows in `gis.underground_assets` | Utility-owner-authorised, source-dated geometry and documented data-sharing permissions |
| Survey evidence | 0 rows in `gis.asset_survey_evidence` | Field capture, positional accuracy, depth/vertical datum where applicable, evidence and owner verification |
| Operational conflict screening | Software RPC exists, but verified asset registry is empty | Authorised assets plus independently reviewed test cases and device acceptance |
| Subsurface 3D | No verified utility geometry/depth model | Surveyed geometry, depth, vertical datum, accuracy and field validation |
| On-device GIS acceptance | CI can compile; physical-device map, GPS, tile, satellite and role tests remain | Test on supported Android devices with real authenticated accounts |

The public utility-source catalogue may contain aggregate feature counts. Those are catalogue metadata, not imported SAMANVAY assets. The audited registry has 11 restricted source records with zero operational approvals; `gis.underground_assets` and `gis.asset_survey_evidence` remain empty. An empty verified-asset registry means **data unavailable**, not that the ground is clear of utilities.

## Reproducible live checks

```sql
-- Import batch result
select id, import_status, rows_received, rows_inserted, rows_rejected,
       completed_at
from public.india_directory_import_batches
where id = '441de866-f89d-4505-bfbc-2d14ae9d81cc';

-- District reference totals, parent coverage and LGD-code treatment
select count(*) as district_rows,
       count(distinct state_ut_id) as state_ut_parents,
       count(*) filter (where lgd_code is null) as rows_without_lgd_code,
       count(*) filter (where verification_status = 'imported_unverified') as unverified_rows
from public.india_administrative_units
where import_batch_id = '441de866-f89d-4505-bfbc-2d14ae9d81cc';

-- State/UT distribution
select s.name as state_ut, count(u.id) as district_reference_rows
from public.india_state_uts s
left join public.india_administrative_units u
  on u.state_ut_id = s.id
 and u.import_batch_id = '441de866-f89d-4505-bfbc-2d14ae9d81cc'
group by s.id, s.name
order by s.name;
```

## Phase 2 closure decision

**Completed in this execution:** 733 national district-name reference records imported, 36/36 State/UT parents matched, source provenance recorded, import batch audited, and the map navigator updated to use the new source only as an explicitly labelled fallback.

**Not complete:** current statutory LGD hierarchy, local bodies/wards, persisted official boundary polygons, owner-authorised utility assets, field evidence, operational conflict validation and physical-device acceptance.

Phase 2 therefore remains **not 100% operationally complete**. No fabricated utility geometry, invented LGD codes, field evidence or “no conflict” clearance has been introduced.
