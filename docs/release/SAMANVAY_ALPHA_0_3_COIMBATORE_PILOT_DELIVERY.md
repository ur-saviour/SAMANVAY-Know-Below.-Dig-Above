# SAMANVAY Alpha 0.3 — Coimbatore Pilot Delivery Record

**Date:** 6 November 2026  
**Branch:** `feature/alpha-03-integrated-platform`  
**Purpose:** Record the tested pilot build and the public data genuinely acquired for Coimbatore, with limitations made explicit.

## 1. Deliverable status

| Component | Result | Evidence |
|---|---|---|
| Android APKs | Successful | [Android build run 42185353338](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42185353338) |
| Browser portal package | Successful | [Browser build run 42185851916](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42185851916) |
| Coimbatore 2024 ward polygons | Imported and validated | `app/assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson` |
| GIS data governance and provenance | Documented | [Open reference data register](../data-governance/COIMBATORE_OPEN_REFERENCE_DATA_REGISTER.md) |
| Authoritative underground-utility geometry | Not acquired | Supabase GIS asset registry has zero rows |

## 2. Android release assets

The Alpha 0.3 GitHub prerelease contains ABI-specific APKs:

- [ARM64 APK — recommended for most modern Android phones](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-arm64-v8a.apk)
- [ARMv7 APK](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-armeabi-v7a.apk)
- [x86_64 APK](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/download/samanvay-alpha-0.3/SAMANVAY-Alpha-0.3-x86_64.apk)

All three files passed APK ZIP-integrity checks, `aapt` package inspection, Android v2 signature verification and `zipalign -c -v 4`. The v2 signer is the temporary Android Debug certificate (SHA-256 `dd25bad547153ee41295691da9bd051ecada53afb41e1a1eb83e879413c94b8f`). This is a validated pilot/development build, not a production-signed release. A persistent owner-controlled release keystore must be configured before distribution as a stable production app. Because CI debug signing can change between runs, installing this build over a previous APK may require a clean install; uninstalling may remove device-only app data.

## 3. Browser portal

The browser portal was built and packaged successfully in [run 42185851916](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42185851916). The downloaded artifact contains the `web/` site bundle and includes the same ward GeoJSON asset at `web/assets/assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`. The artifact can be downloaded from the run's `SAMANVAY-Browser-Portal` artifact. This records a build package; it does not claim a public production domain has been deployed.

## 4. Public data acquired and integrated

### COIM-WARD-2024 — Coimbatore Wards Map 2024

- Publisher catalogue: OpenCity.in; underlying source listed as `livingatlas.esri.in`.
- Catalogue description: Coimbatore's 100 wards as of 2024.
- Resource format: KML; this repository stores a converted GeoJSON FeatureCollection.
- Catalogue licence field: Other (Public Domain); catalogue credit: OpenCity.in.
- Catalogue metadata: data updated 25 November 2025; metadata updated 27 November 2025.
- Conversion validation: 100 placemarks converted to 100 polygons; 0 skipped; 23,403 coordinate vertices; 100 unique ward numbers; coordinate ranges valid for WGS 84; rings closed; 20 wards per each of five zones.
- In-app layer: optional “Coimbatore ward boundaries (2024 reference)” MapLibre overlay, independent of restricted utility access.

Source: https://data.opencity.in/dataset/coimbatore-wards-map  
Resource metadata: https://data.opencity.in/dataset/coimbatore-wards-map/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be

**Legal/operational limit:** The open dataset is described as a 2024 reference and is not a CCMC-issued or CCMC-certified statutory GIS boundary. The app labels it as a reference. The latest CCMC Gazette and delimitation records remain authoritative for legal ward boundaries: https://www.ccmc.gov.in/index.php/createpage/delimitation-of-ward

### Surface basemap context

The map uses the OpenFreeMap Liberty vector style, whose map data is OpenStreetMap-derived. It supplies mapped surface context such as roads, streets, buildings, surface water features and labels. It is not a separately downloaded Coimbatore road-ownership register, stormwater asset inventory, or underground utility survey.

Basemap style: https://tiles.openfreemap.org/styles/liberty  
Attribution: https://openfreemap.org/ and OpenStreetMap contributors.

## 5. Public data located but not imported

| Dataset | Finding | Why not in the app data yet |
|---|---|---|
| Coimbatore District waterbody maps | Official district page lists PDF maps for 11 taluks | PDFs are not machine-readable GIS; they were not digitised into coordinates |
| NWDP Tamil Nadu surface-waterbody boundaries | Satellite-derived boundaries for waterbodies larger than 0.1 ha; SHP; last updated 5 May 2025; licence field “Other (Open)” | Download endpoint was unreachable in this build session; no file bytes or features were validated |
| Tamil Nadu groundwater telemetry | Six-hourly station observation dataset identified on NWDP | CSV download endpoint was unreachable; no observations were inserted |
| Tamil Nadu Water Bodies Census (Jal Dharohar) | 2018–19 census resources listed in 2023; OpenCity catalogue indicates CC BY-NC 2.0 | Non-commercial restriction is unsuitable to assume for a platform with undefined future deployment/commercial status; not copied |

Official and catalogue source links are maintained in the open reference data register. No synthetic waterbody, road or utility geometry was created.

## 6. Underground assets — current truth

The Supabase `gis.underground_assets` registry currently contains **zero records**. There is no imported and verified Coimbatore dataset of buried water mains, sewer pipes, stormwater conduits, electricity cables, telecom ducts, gas pipelines or borewells.

Consequently:
- The 2024 ward polygons and OpenStreetMap basemap are context layers only.
- The app does not infer underground utility alignment from road maps, surface water, satellite imagery or empty map results.
- Exact utility geometry remains restricted to the owning department and explicitly authorised cross-agency roles.
- The department map layer only receives the department's own verified assets through the authenticated, owner-scoped RPC.
- Unverified asset geometry remains withheld.
- An empty registry means “no authorised underground asset record is registered”; it does not mean “no utility exists” or that a location is safe for excavation.
- Clash/proximity information is advisory and does not replace statutory clearance or field verification by the responsible owner.

## 7. Next authorisation and data steps

1. Reconcile the OpenCity 2024 ward reference with the current CCMC Gazette and obtain written CCMC confirmation or an official machine-readable layer.
2. Request road ownership, road-cut permits, restoration status and planned-work records from CCMC, State Highways or NHAI according to segment ownership.
3. Request scheme-specific water and sewer records from CCMC/TWAD, with exact asset owner and maintenance boundary.
4. Request the approved surface-waterbody / stormwater GIS records from CCMC and PWD/WRD.
5. Request restricted underground electricity data from TNPDCL and telecom/gas data from each actual asset owner through approved secure channels.
6. Import only after recording licence, written permission, CRS, accuracy, source date, custodian, data dictionary, checksum and verification status.

See [Coimbatore Pilot Authority Mapping](../data-governance/COIMBATORE_PILOT_AUTHORITY_MAPPING.md) and [Coimbatore Data-Sharing Request Templates](../data-governance/COIMBATORE_DATA_SHARING_REQUEST_TEMPLATE.md).

## 8. Release conclusion

SAMANVAY Alpha 0.3 now packages an optional, validated public Coimbatore ward-reference GIS layer in both Android and browser builds, alongside the existing multi-department case coordination app and access-controlled underground asset framework. This is a meaningful public-data pilot baseline. It is not yet a populated underground utility registry and must not be presented as a complete or certified underground map.