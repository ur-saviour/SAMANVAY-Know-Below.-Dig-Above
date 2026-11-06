# Coimbatore open reference data register — SAMANVAY

**Checked:** 6 November 2026  
**Pilot:** Coimbatore City Municipal Corporation area  
**Purpose:** Record public datasets that can be used immediately without claiming restricted government access or treating reference layers as underground utility records.

## 1. Imported into the repository and Android map

### COIM-WARD-2024 — Coimbatore ward boundaries

| Field | Value |
|---|---|
| Dataset | Coimbatore Wards Map 2024 |
| Publisher | OpenCity.in catalogue |
| Underlying source | livingatlas.esri.in |
| Description | Coimbatore ward map described as 100 wards as of 2024 |
| Data last updated | 25 November 2025 |
| Format supplied | KML |
| Catalogue licence | Other (Public Domain) |
| Catalogue credit | OpenCity.in |
| Repository format | GeoJSON FeatureCollection |
| Feature count | 100 polygons |
| Conversion result | 100/100 placemarks converted; zero skipped |
| Vertex count | 23,403 |
| Coordinate system | WGS 84 longitude/latitude |
| Geographic extent | 76.8576557°E–77.0628924°E; 10.9143712°N–11.1054671°N |
| Repository path | app/assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson |
| Map availability | Optional MapLibre layer: “Coimbatore ward boundaries (2024 reference)” |

Sources:
- Dataset: https://data.opencity.in/dataset/coimbatore-wards-map
- Resource metadata: https://data.opencity.in/dataset/coimbatore-wards-map/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be
- Source KML: https://data.opencity.in/dataset/bcedc1ea-ba01-468d-83c2-6aa5afe74db0/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be/download/3111f6d4-f8db-44c2-a608-61c975e9b744.kml

**Use boundary:** The OpenCity catalogue describes this as a 2024 map and marks the resource Public Domain. It is not a CCMC-issued statutory GIS dataset and must not be represented as officially certified. Validate it against CCMC's current Gazette/delimitation records before using it for administrative, property, engineering or legal decisions.

CCMC's official delimitation page publishes the Ward Delimitation Format 2D, Delimitation Ward Map and All Ward Delimitation Gazette Notification:
- https://www.ccmc.gov.in/index.php/createpage/delimitation-of-ward

The in-app label explicitly says reference and directs users to confirm legal boundaries with CCMC. The overlay is independent of request routing, utility ownership, approvals and excavation-clearance logic.

## 2. Context data already available through the map basemap

### OSM-CTX-001 — surface road and place context

The Flutter map's no-key vector basemap is:
- Style: https://tiles.openfreemap.org/styles/liberty
- Provider: OpenFreeMap
- Underlying community mapping: OpenStreetMap-derived map data

This provides visual surface context such as mapped roads, streets, buildings, water features and place labels according to the current style's source layers. The app's Photon place-search fallback also uses OpenStreetMap data.

**Use boundary:** Basemap roads and visible water features are reference context. They do not establish road ownership, underground pipe/cable alignment, utility depth, survey accuracy, asset condition or legal clearance. The basemap is served as tiles; this register does not claim that a separate complete Coimbatore road-network GeoJSON has been downloaded into the repository.

Retain OpenFreeMap and OpenStreetMap contributor attribution in accordance with their current terms.

## 3. Public data identified but not imported

### TN-GW-TELEMETRY-6H — Tamil Nadu groundwater telemetry

The National Water Data Portal lists a six-hourly groundwater-level telemetry dataset produced by the Tamil Nadu Surface Water and Ground Water departments. The portal describes station observations, timestamp, geographic hierarchy and groundwater depth below ground level, and lists CSV/API resources for 2021–2025 and 2026–2030.

Official portal: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw

**Status:** Located and metadata reviewed; CSV bytes were not successfully retrieved during this build session, so no groundwater values have been inserted into SAMANVAY. The portal's resource metadata lists an open licence category, but the specific resource terms and API contract should be rechecked before production use.

**Intended use when retrieved:** A separate groundwater monitoring time-series table with station ID, timestamp, reported depth, unit, geographic hierarchy, source dataset, update date and provenance. This is not a private borewell register, permission register or underground utility geometry.

## 4. Not imported — access or authority boundary

| Candidate | Why not imported now | Required next step |
|---|---|---|
| TNGIS administrative / thematic layers | Portal registration and dataset-specific terms/permissions apply; the current catalogue must be checked layer by layer | Obtain current download/API access and confirm each layer's licence, CRS, version and custodian |
| CCMC ward Gazette and statutory map | Official documents are published, but a current machine-readable GIS dataset has not been verified in the project | Reconcile the 2024 OpenCity reference polygons to the current Gazette/map and obtain CCMC confirmation |
| CCMC UGD / stormwater network | Public service pages and GIS history do not equal a complete current utility GIS export | Request current owner-held as-built/survey geometry through the Corporation's approved data-sharing route |
| TWAD water/sewer assets | Asset ownership is scheme-specific; no current authorised Coimbatore export is in the repo | Obtain TWAD / scheme-owner records and permission |
| TNPDCL underground assets | Exact operational utility routes are restricted owner data; public GIS references do not expose a complete downloadable network | Obtain written permission and authorised secure transfer from the utility |
| Telecom / gas routes | No complete, open and authoritative city-wide buried network dataset verified | Request data from each actual asset owner/operator |

## 5. How the imported layer is used in SAMANVAY

- Static GeoJSON is bundled as a Flutter asset and rendered in MapLibre.
- It is available to signed-in map users as a public administrative reference.
- It has its own layer toggle and does not grant access to restricted GIS tables.
- It is visually distinct from verified department-owned underground assets and aggregate coverage cells.
- It does not create GIS underground-asset rows and is not used by the excavation coordination check.
- It cannot mark a site clear or safe for excavation.

## 6. Current data truth

| Data class | Current state |
|---|---|
| Coimbatore ward reference polygons | 100 open reference polygons bundled in the app |
| Surface road / place basemap context | Served by OpenFreeMap / OpenStreetMap-derived vector tiles |
| Official current ward certification | Not yet confirmed against CCMC Gazette by the Corporation |
| Groundwater telemetry CSV | Identified; not imported |
| Coimbatore underground water/sewer/stormwater/power/telecom/gas geometry | Not acquired / not registered |
| Supabase underground asset registry | Remains empty unless and until authorised asset-owner records are imported and verified |

**Safety wording:** “No authorised underground asset record is registered or returned” is not equivalent to “no utility exists” or “the site is safe”. Actual clearance must come from the relevant utility owner and prescribed field verification.
## 7. Additional surface-water sources identified — not imported

### 7.1 Coimbatore District official taluk waterbody maps

The Coimbatore District Administration publishes a waterbody page listing map PDFs for 11 taluks: Coimbatore South, Madukkarai, Perur, Sulur, Coimbatore North, Mettupalayam, Annur, Pollachi, Kinathukadavu, Valparai and Anamalai. These are official local reference documents and can help identify the relevant waterbody records and custodians for a pilot. The page provides PDF maps, not a machine-readable GIS export.

Official source: https://coimbatore.nic.in/waterbody/

**Status:** Catalogue and document links located; PDFs have not been digitised into GIS. A PDF location map must not be treated as survey-grade geometry or a current underground drainage network.

### 7.2 National Water Data Portal — Tamil Nadu surface-waterbody boundaries

NWDP publishes a Tamil Nadu-wide surface-waterbody boundary resource described as satellite-derived boundaries for waterbodies larger than 0.1 hectare. The resource metadata states:
- Format: Shapefile (SHP)
- Last updated: 5 May 2025
- Licence field: Other (Open)
- Resource download: https://nwdp.nwic.gov.in/dataset/811f6a62-61c2-4d79-b90b-deeee4151f6d/resource/b53491de-0ab9-4f59-8071-8a9cfead60c3/download/wb_tn_shp.zip
- Metadata page: https://nwdp.nwic.gov.in/dataset/surface-waterbodies/resource/b53491de-0ab9-4f59-8071-8a9cfead60c3

**Status:** Metadata inspected; the shapefile endpoint was unreachable during this build session. No shapefile bytes, feature count, CRS or Coimbatore subset have been imported or validated. Re-attempt retrieval through the data portal's supported download/API process before ingestion. Even when obtained, this dataset is surface-waterbody context, not a stormwater pipe/drain asset inventory.

### 7.3 Tamil Nadu Water Bodies Census — Jal Dharohar

OpenCity lists 2023 KML resources from the 2018–19 Water Bodies Census conducted by the Department of Water Resources, River Development and Ganga Rejuvenation. The dataset catalogue exposes a **CC BY-NC 2.0** licence. Because that licence includes a non-commercial condition and SAMANVAY's future deployment/commercial status is not established, these resources have not been copied into the app. Review the licence and intended use with the data publisher before redistribution.

Source: https://data.opencity.in/dataset/tamil-nadu-water-bodies-census-data

## 8. Data import acceptance rule

Only import a downloaded GIS file after confirming actual bytes, file integrity, feature count, geometry type, CRS, attribute schema, licence and intended-use compatibility. Preserve the source file, checksum, publisher, source URL, last-updated date and transformation script. Do not turn satellite-derived waterbody polygons or district PDF map labels into underground stormwater pipes or legal excavation clearance.