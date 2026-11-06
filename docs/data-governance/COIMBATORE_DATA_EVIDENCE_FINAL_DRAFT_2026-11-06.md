# SAMANVAY — Coimbatore Public Data Evidence Pack
## Final data-readiness draft — 6 November 2026

**Project:** SAMANVAY — Know Below. Dig Above.  
**Pilot geography:** Coimbatore district, Tamil Nadu, with CCMC jurisdiction distinguished from the wider district.  
**Purpose:** Provide a source-traceable, technically honest data baseline for the Alpha 0.3 GIS demonstration.

## 1. Executive finding

SAMANVAY has two real spatial reference datasets in its repository and a third official source index. The reference datasets are useful for a GIS demonstration, spatial context and pilot planning. They are **not** a substitute for an owner-authorised underground-utility inventory.

The data baseline is:

1. **100 Coimbatore ward-reference polygons (2024)** from the OpenCity catalogue, whose resource metadata labels the source Public Domain.
2. **21 groundwater telemetry monitoring-station points** for Coimbatore district from the Tamil Nadu Surface Water and Ground Water Departments, distributed through the National Water Data Portal (NWDP/NWIC). Each point preserves its own latest available observation timestamp and measurement.
3. **11 official Coimbatore taluk waterbody-map PDF links** indexed from the Coimbatore District Administration. The PDFs have not been digitised into GIS geometry.

The Supabase underground-asset registry is a separate system. It must remain empty until owner-supplied or properly surveyed utility geometry is imported and verified. An empty registry does not mean that no buried utilities exist.

## 2. Spatial datasets already present in the repository

| Dataset | Source and reuse status | Actual content | Intended use | Limitations |
|---|---|---:|---|---|
| Coimbatore wards (2024 reference) | OpenCity.in catalogue; resource metadata states Public Domain and credits OpenCity.in; original source recorded as livingatlas.esri.in | 100 polygon features | Ward context and pilot grouping | Not CCMC-certified current statutory boundaries; confirm with current Gazette/CCMC before jurisdiction decisions |
| Tamil Nadu groundwater telemetry (2026–2030) | Tamil Nadu Surface Water and Ground Water Departments via NWDP/NWIC; resource metadata says “Other (Open)” | 21 Coimbatore-district station points, one latest available record per station | Groundwater monitoring context and station-level display | Not a private borewell register, permit register, water-pipeline map, aquifer-safety certificate or live feed |
| Coimbatore taluk waterbody map index | Coimbatore District Administration | 11 official PDF document links | Evidence/source discovery | Index only; no extracted GIS geometry or feature count |

### 2.1 Repository file paths

The Android build consumes the root-level `assets/` directory:

- `assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`
- `assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson`
- `data/reference/coimbatore_waterbody_map_index.csv`

The app's Dart entry point is `app/main.dart`. Its MapLibre layer loaders reference the same GeoJSON asset names through Flutter's `rootBundle`.

### 2.2 Groundwater telemetry validation snapshot

- NWDP dataset: Ground Water Level (Telemetry — Six Hourly), Tamil Nadu SW GW.
- NWDP resource ID: `6857c02f-c77e-4576-b349-3e45aacc1c21`.
- Source period: 2026–2030.
- Source portal last-update metadata checked: 6 November 2026.
- Imported station features: 21.
- Distinct feature IDs: 21.
- District attribute: Coimbatore for all 21 features.
- Invalid/out-of-range WGS84 coordinate pairs: 0.
- Missing station measurements in this snapshot: 0.
- Observation timestamps represented in the snapshot range from 1 October 2026 to 5 November 2026; the latest observation is 5 November 2026 at 12:00 (source local-time convention should be confirmed with the producer).
- Geographic extent of the points: 76.84441667°E–77.27441667°E and 10.327933°N–11.194°N. This is district-wide and extends beyond the CCMC city boundary.

**Interpretation:** The file is a dated station snapshot, not a continuously streaming feed. Station timestamps differ. The source measurement field is retained without silently changing its sign convention or assuming a groundwater-depth datum. The source's `RL_MSL` field is retained where present.

### 2.3 Ward reference validation

- 100 ward polygon features.
- 23,403 coordinate vertices in the converted source rings.
- WGS84 longitude/latitude.
- The catalogue describes the data as Coimbatore's 100 wards as of 2024.
- This is an administrative reference layer only. Current CCMC Gazette and official Corporation records take precedence.

### 2.4 Official waterbody PDF index

The CSV index contains these 11 taluks: Coimbatore South, Madukkarai, Perur, Sulur, Coimbatore North, Mettupalayam, Annur, Pollachi, Kinathukadavu, Valparai and Anamalai.

The index links to the Coimbatore District Administration source page and its PDF resources. No PDF has been represented as a GIS polygon, no coordinates have been invented, and no PDF has been re-labelled as an underground drainage inventory.

## 3. GIS integration and build acceptance

The app code contains separate MapLibre loaders and controls for:

- Coimbatore ward-reference polygons;
- groundwater telemetry station points, including station details and source observation time;
- user work-request locations subject to Supabase access controls; and
- owner-scoped verified underground-asset geometry, when authorised records exist.

The 3D basemap/building extrusion is city-context visualisation. It is not a three-dimensional model of buried pipes, cables or ducts.

### APK asset packaging acceptance

A previous Alpha 0.3 CI run completed package/signature/alignment checks but the resulting APKs did not contain the two GeoJSON files in Flutter's asset bundle. The build workflow has now been amended to:
1. declare both GeoJSON assets in the generated Flutter `pubspec.yaml`;
2. verify both source files exist before build; and
3. fail the APK verification step if either GeoJSON is absent from any ABI-specific APK.

**Verified release evidence:** GitHub Actions run [42190005968](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42190005968) completed successfully, including APK package/signature/alignment checks. I downloaded and inspected its three ABI APKs and confirmed that both GeoJSON files are present inside each APK at `assets/flutter_assets/assets/reference/coimbatore/`. The ARM64 APK SHA-256 is `49d1c6e2a352360c78216538e27d47c8830e2e5cdabda4698c184691bb245d64`.

A follow-up workflow run [42191020032](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42191020032) adds mandatory automated checks that fail the build if either GIS asset is absent. That follow-up run was still in progress when this draft was updated. A successful Dart analysis alone is not proof that runtime assets were packaged.

## 4. Official sources identified but not copied into the app

| Source | Relevant data | Current decision |
|---|---|---|
| TNGIS / TNeGA | Administrative layers, roads, drainage context, tanks, reservoirs, rivers and departmental GIS | Catalogue identified. Do not mirror or redistribute layers without the applicable TNeGA and data-owner approvals |
| CCMC | Current ward/Gazette data, road inventory and ownership, road-cutting records, underground sewerage system and stormwater asset registers | Official source pages/workflows identified; current machine-readable utility geometry has not been supplied |
| TWAD Board | Scheme-specific water and sewer networks, as-built drawings and maintenance boundaries | Obtain scheme ownership and data-sharing permission |
| TNPDCL | Distribution GIS, feeders and underground cable records | Exact network access is controlled; do not infer public availability from a GIS portal link |
| PWD / WRD | Tanks, channels, canals, flood-control and water-resource assets | Public context portals identified; use the actual custodian's records and approvals |
| Telecom and gas operators | Ducts, fibre routes and pipelines | Identify the actual operator/asset owner corridor by corridor; no authorised route dataset acquired |

## 5. What SAMANVAY can demonstrate now

- A Coimbatore ward-reference layer with 100 polygons.
- A district-wide groundwater telemetry context layer with 21 monitoring-station points and source timestamps.
- A source index to 11 official taluk-level waterbody map documents.
- Device GPS and work-request location workflows.
- Department-scoped access architecture for exact underground utility geometry.
- A controlled import/verification pathway for owner-supplied GeoJSON.

## 6. What must not be claimed

SAMANVAY does not currently have:

- a complete underground water, sewer, stormwater, electricity, gas or telecom network map;
- a complete register of permitted or illegal private borewells;
- a current live groundwater feed for every monitoring station;
- a legally certified current ward boundary layer based solely on the 2024 OpenCity reference;
- automated statutory excavation clearance or a guarantee that an area is safe to dig; or
- proof that an area has no utilities because the database has no record.

Groundwater telemetry stations must never be represented as borewell locations. Surface waterbody records must never be re-labelled as buried drains or pipelines.

## 7. Data acquisition and verification sequence

1. Use the existing public ward and groundwater reference layers for demonstration only.
2. Obtain the current CCMC ward Gazette, road ownership inventory and road-cutting records.
3. Request CCMC UGD and stormwater as-built GIS with CRS, positional accuracy, source date, owner, maintenance authority and permitted-use terms.
4. Request TWAD scheme-level water/sewer asset data and confirm which agency owns each network segment.
5. Request TNPDCL and other utility-owner data through their designated authorised channels.
6. Record licence/permission and custodian metadata before ingestion.
7. Validate geometry, CRS, positional accuracy, topology and source freshness.
8. Import as UNVERIFIED; require owner-authorised review or verified survey evidence before operational display.
9. Keep exact utility geometry restricted to authorised owner/department roles. Do not expose it to public/requester accounts.
10. Treat clash and proximity alerts as advisory; statutory road-cutting and excavation approvals remain with the competent authority.

## 8. Source links

- NWDP groundwater telemetry dataset: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw
- NWDP 2026–2030 CSV resource: https://nwdp.nwic.gov.in/dataset/16efa917-4b91-473b-969d-57d1bcd11924/resource/6857c02f-c77e-4576-b349-3e45aacc1c21/download/gwl_tel_6_hourly_tamil_nadu_sw_gw_tn_2026_2030.csv
- OpenCity Coimbatore ward dataset: https://data.opencity.in/dataset/coimbatore-wards-map
- CCMC ward delimitation: https://www.ccmc.gov.in/index.php/createpage/delimitation-of-ward
- CCMC GIS information: https://www.ccmc.gov.in/index.php/createpage/geographical-information-system-and40gisand41
- Coimbatore District Administration waterbody maps: https://coimbatore.nic.in/waterbody/
- TNGIS portal: https://tngis.tn.gov.in/
- TNGIS catalogue and terms: https://tngis.tn.gov.in/apps.html
- Tamil Nadu State GIS Portal: https://stategisportal.nic.in/stategisportal/Home/State/33

## 9. Final data-readiness statement

**Ready for a controlled prototype demonstration:** 100 ward-reference polygons, 21 groundwater monitoring-station points, and an index of 11 official taluk waterbody-map PDFs.

**Not ready for operational excavation coordination:** exact owner-authorised underground utility networks, current road ownership, current statutory ward verification, and formal data-sharing permissions are still outstanding.

This distinction is deliberate. SAMANVAY should demonstrate traceable public context data now while protecting the integrity and confidentiality of exact underground infrastructure records.
