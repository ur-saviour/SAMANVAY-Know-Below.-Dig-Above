# Coimbatore ward reference data

## Active map layer

**File:** `coimbatore_wards_2024_public_domain.geojson`  
**Dataset title:** Coimbatore Wards Map 2024  
**Publisher listing:** OpenCity.in  
**Underlying source:** livingatlas.esri.in  
**Source resource format:** KML  
**Resource metadata:** 25 November 2025 update; dataset described as Coimbatore's 100 wards as of 2024  
**License stated by resource catalogue:** Other (Public Domain)  
**Credit stated by resource catalogue:** OpenCity.in  
**Converted format:** GeoJSON FeatureCollection, WGS 84 longitude/latitude  
**Validated conversion:** 100 placemarks converted to 100 polygon features; no features skipped; 23,403 coordinate vertices in source rings  
**Approximate extent:** 76.8576557°E–77.0628924°E, 10.9143712°N–11.1054671°N

### Attribution and source references

- OpenCity dataset: https://data.opencity.in/dataset/coimbatore-wards-map
- Resource metadata: https://data.opencity.in/dataset/coimbatore-wards-map/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be
- Original KML download: https://data.opencity.in/dataset/bcedc1ea-ba01-468d-83c2-6aa5afe74db0/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be/download/3111f6d4-f8db-44c2-a608-61c975e9b744.kml

The dataset catalogue labels the resource **Public Domain** and credits OpenCity.in. The original source is listed as livingatlas.esri.in. This repository keeps those attribution details and the original catalogue link.

## Operational limitations

This is an open reference dataset described as “as of 2024”; it is **not represented as a CCMC-certified current statutory boundary layer**. It must not be used alone to determine legal jurisdiction, road ownership, property/building approval jurisdiction, service entitlement or excavation clearance.

CCMC's official delimitation page separately publishes the current ward-delimitation map and Gazette notification. The official Gazette and the Corporation's currently maintained records take precedence:
- https://www.ccmc.gov.in/index.php/createpage/delimitation-of-ward

The app labels this as a reference layer and keeps it separate from case permissions, asset ownership and underground utility geometry. Before operational rollout, compare it with the latest CCMC Gazette/map and obtain written confirmation of the effective boundary version.

## Archived historical reference

`coimbatore_wards_legacy_2011.geojson` is retained as an older open dataset from datameet/Municipal_Spatial_Data, licensed CC BY-SA 2.5 India. It is not used by the current app overlay:
- https://github.com/datameet/Municipal_Spatial_Data/tree/master/Coimbatore

The 2011 dataset must retain its share-alike attribution if redistributed or adapted.

## What this dataset does not contain

These are administrative ward polygons only. They do **not** describe buried water pipes, sewer mains, underground stormwater drains, electricity cables, telecom ducts, gas pipelines, borewells or verified excavation clearances.
