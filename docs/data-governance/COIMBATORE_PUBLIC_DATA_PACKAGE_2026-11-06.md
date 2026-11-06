# Coimbatore public data package — 6 November 2026

**Repository branch:** `feature/alpha-03-integrated-platform`  
**Pilot:** Coimbatore, Tamil Nadu  
**Purpose:** State exactly which real public datasets and official source references are available to SAMANVAY, and prevent reference material from being mistaken for authorised underground utility geometry.

## Data already bundled in the app

| Dataset | Source / licence status | Content | App use | Limit |
|---|---|---:|---|---|
| Coimbatore ward boundaries (2024 reference) | OpenCity.in catalogue; resource marked Public Domain; source attribution recorded in the existing data register | 100 polygons | Optional MapLibre ward layer | Not CCMC-certified statutory boundaries; verify against current Gazette |
| Tamil Nadu groundwater telemetry (2026–2030) | NWDP / NWIC dataset produced by Tamil Nadu Surface Water and Ground Water Departments; resource metadata says “Other (Open)” | 21 Coimbatore district station points with latest available observation and timestamp | Separate switchable GIS point layer | Monitoring stations and measurements only; not borewell register, pipes or cables |

Existing assets:
- `app/assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`
- `app/assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson`

## New source index committed in this change

- File: `data/reference/coimbatore_waterbody_map_index.csv`
- Rows: 11 official PDF map links, one for each taluk listed by the Coimbatore District Administration.
- Publisher: Coimbatore District Administration.
- Source page: https://coimbatore.nic.in/waterbody/
- Source page last updated: 10 August 2026.
- Contents: taluk name, publisher, source page, document type, direct PDF URL, and explicit geometry status.
- Geometry: none. The CSV is a document index only; no coordinate or polygon has been generated from a PDF.

The district page lists Coimbatore South, Madukkarai, Perur, Sulur, Coimbatore North, Mettupalayam, Annur, Pollachi, Kinathukadavu, Valparai and Anamalai. The original documents are linked rather than copied. Their reuse terms and technical accuracy must be confirmed before republishing or digitising them.

## Other official sources identified, not yet imported

1. **TNGIS / TNeGA:** More than 400 spatial layers are hosted; public catalogue pages show layers such as roads, drainage, tanks, reservoirs and rivers. TNGIS states that ownership remains with contributing departments and commercial use requires TNeGA approval. Do not scrape or mirror restricted layers.
2. **OGD India — Landmark Data, Coimbatore:** Dataset is attributed to Tamil Nadu Municipal Administration and Water Supply Department / Commissionerate of Municipal Administration; published 9 December 2013 and updated 12 February 2025. The portal page exposes a ZIP-download entry, but the dataset bytes were not successfully retrieved and validated in this session. It is not claimed as imported.
3. **NWDP surface-waterbody boundaries:** A Tamil Nadu shapefile resource is listed with a 5 May 2025 update and “Other (Open)” licence metadata. Download endpoint was not reachable in this session; no file, feature count, CRS or Coimbatore subset is claimed.
4. **Coimbatore District waterbody PDF maps:** The official page and all 11 document links are indexed in the CSV. These are not a GIS export.

## Data integrity and safety rules

- Never populate `gis.underground_assets` from ward polygons, groundwater stations, surface-waterbody boundaries, OSM basemaps or PDF map labels.
- Never treat a groundwater station as a borewell, nor a surface waterbody as a stormwater drain or buried pipeline.
- Never treat absence of a record as evidence that no utility exists or that excavation is safe.
- Exact utility geometry must come from the asset owner or an approved survey/as-built record, retain source lineage, and pass the project's verification workflow.
- Before operational use, validate dataset licence, source date, CRS, geometry validity, positional accuracy, custodian and update cadence.

## What this delivers now

SAMANVAY's Coimbatore pilot has two real spatial reference layers already integrated in the app, plus an official district waterbody document index committed to the repository. It does **not** yet have a complete authorised underground water, sewer, stormwater, power, telecom or gas network. That gap cannot be closed honestly without the relevant owner-approved data or verified field surveys.
