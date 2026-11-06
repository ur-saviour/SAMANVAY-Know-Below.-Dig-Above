# Coimbatore Wards Map 2024 — source and licence record

**Dataset:** Coimbatore Wards Map 2024  
**Publisher / catalogue:** OpenCity.in  
**Original source recorded by OpenCity:** livingatlas.esri.in  
**Resource format:** KML  
**Source resource ID:** 3a068058-d69d-4621-8f2a-e3dcfa7224be  
**Source resource page:** https://data.opencity.in/dataset/coimbatore-wards-map/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be  
**Direct source download:** https://data.opencity.in/dataset/bcedc1ea-ba01-468d-83c2-6aa5afe74db0/resource/3a068058-d69d-4621-8f2a-e3dcfa7224be/download/3111f6d4-f8db-44c2-a608-61c975e9b744.kml  
**Dataset description:** Wards map of Coimbatore as of 2024 with 100 wards.  
**OpenCity resource metadata licence:** Public Domain  
**OpenCity credit field:** OpenCity.in  
**Metadata record last modified:** 25 November 2025  
**Retrieved and converted:** 6 November 2026

## Conversion record

The original KML was parsed into a GeoJSON FeatureCollection in WGS84 longitude/latitude order (EPSG:4326 semantics). The resulting file is:

`assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`

Validation performed:
- 100 placemarks / 100 GeoJSON features.
- 100 polygon geometries (stored as MultiPolygon to preserve a consistent geometry type).
- 23,403 coordinate positions across the polygon rings.
- All polygon rings were closed.
- The first source attribute is retained as `ward_number`; the second is retained as `district`; remaining source attributes are retained without guessed meanings in `source_attributes`.

## Correct use in SAMANVAY

This layer is a **public administrative reference dataset**, not an underground utility dataset. It must not be inserted into `gis.underground_assets`, used as proof of current statutory ward boundaries, or used as a substitute for CCMC confirmation.

The map UI labels it “Coimbatore ward boundaries (2024 reference)” and indicates that current legal boundaries must be confirmed with CCMC. Users should compare it with the latest official corporation Gazette / ward data before using it for jurisdiction decisions.

No underground water, sewer, stormwater-pipe, electricity, gas or telecom geometry is contained in this dataset. Its source and public-domain metadata do not confer access to restricted asset-owner information.

## Attribution and reuse note

OpenCity's CKAN resource metadata identifies the licence as **Public Domain** and gives the credit **OpenCity.in**. This source record is preserved here for traceability. For good attribution practice, SAMANVAY retains the OpenCity credit and direct source links even though the resource is marked Public Domain. Recheck the source metadata before future replacement or refresh.
