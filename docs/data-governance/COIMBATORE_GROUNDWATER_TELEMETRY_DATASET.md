# Coimbatore Groundwater Telemetry — Source, Licence and Ingestion Record

**SAMANVAY layer:** Groundwater telemetry stations (2026–2030)  
**Geographic scope:** Coimbatore district, Tamil Nadu (district-wide; not limited to CCMC city boundary)  
**Snapshot retrieved:** 6 November 2026  
**Features included:** 21 monitoring stations  
**Latest source observation date in this snapshot:** 5 November 2026

## 1. Authoritative source

- **Publisher / data producer:** Tamil Nadu Surface Water and Ground Water Departments (Tamil Nadu SW GW)
- **Host:** National Water Data Portal (NWDP), National Water Informatics Centre, Department of Water Resources, River Development & Ganga Rejuvenation, Ministry of Jal Shakti, Government of India
- **Dataset page:** https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw
- **2026–2030 CSV resource:** https://nwdp.nwic.gov.in/dataset/16efa917-4b91-473b-969d-57d1bcd11924/resource/6857c02f-c77e-4576-b349-3e45aacc1c21/download/gwl_tel_6_hourly_tamil_nadu_sw_gw_tn_2026_2030.csv
- **CKAN DataStore API resource ID:** `6857c02f-c77e-4576-b349-3e45aacc1c21`
- **Coimbatore district filter:** `District = Coimbatore`
- **API pattern:** `https://nwdp.nwic.gov.in/api/3/action/datastore_search?resource_id=6857c02f-c77e-4576-b349-3e45aacc1c21&filters={"District":"Coimbatore"}`
- **Portal update checked:** 6 November 2026
- **Rows in the source for Coimbatore district at retrieval:** 14,643
- **Distinct station metadata rows reported by the portal query:** 21

The source page describes six-hourly telemetry observations and exposes CSV/API resources. Coordinates, station identifiers, administrative hierarchy, reduced level (where supplied), observation time and the telemetry measurement are present in the source schema.

## 2. What was imported

File:
`assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson`

This is a station-reference snapshot, not a full 14,643-row time series. It contains one latest available source row for each of the 21 distinct station records returned for Coimbatore district. Each GeoJSON feature contains:

- station name and producing agency
- State, District and Tehsil as published by the source
- WGS84 point coordinates in GeoJSON longitude/latitude order
- `rl_msl_m` where supplied
- `observed_at` (source timestamp)
- `groundwater_level_telemetry_m` (source measurement field, copied without sign-convention reinterpretation)
- source resource ID and dataset period

**Freshness is per station.** The latest observation timestamps are not identical: some stations have records from 5 November 2026, while others have older latest rows (for example September or October 2026). The map layer therefore identifies this as a dated telemetry snapshot and preserves the observation timestamp per feature. It must not be described as a live sensor feed.

## 3. Correct interpretation and safeguards

1. These are groundwater telemetry monitoring stations, **not private borewell locations or a borewell-permit register**.
2. The source records cover Coimbatore district, not only Coimbatore City Municipal Corporation. Some stations are in outlying taluks. Do not use the layer as a city-only inventory.
3. The source field is named “Groundwater Level Telemetry 6 Hourly (meter)”. SAMANVAY stores the value without assuming whether negative values mean depth below ground, hydraulic head or another reference convention. Confirm the producer's technical definition before analytical interpretation.
4. `RL_MSL` is retained as the source's reduced-level field in metres where present; null values remain null.
5. This layer is contextual groundwater monitoring data. It is not evidence of underground water-pipeline alignment, borewell legality, aquifer safety or excavation clearance.
6. No private citizen, consumer, borewell-owner or personal data is included in this station snapshot.
7. A station with no recent observation must be shown with its actual observation timestamp; it must not be represented as reporting live.

## 4. Licence and attribution

The NWDP resource metadata classifies the resource licence as **“Other (Open)”**. The page does not present a standard named licence in the retrieved metadata. SAMANVAY therefore preserves source attribution and resource links and treats the file as an academic prototype reference snapshot. Obtain written confirmation from NWIC / Tamil Nadu SW-GW on the precise reuse and redistribution conditions before commercial deployment or broad republication.

**Required attribution:** Tamil Nadu Surface Water and Ground Water Departments; National Water Data Portal / National Water Informatics Centre; Ministry of Jal Shakti, Government of India.

## 5. Refresh procedure

For each refresh:

1. Query the same resource ID with `District = Coimbatore`.
2. Obtain the distinct station list and latest row per station, retaining the original station name and coordinates.
3. Validate coordinates (latitude -90..90, longitude -180..180), station identity, timestamp and numeric measurement.
4. Compare station coordinates with the prior snapshot. Flag material movement for review; do not silently overwrite it.
5. Preserve source timestamps and nulls. Do not interpolate missing values or fabricate observations.
6. Update the GeoJSON and this record with retrieval time, source row counts and a new commit.
7. Keep the layer separate from `gis.underground_assets`.

## 6. Source query and provenance

The snapshot was retrieved through the NWDP CKAN DataStore API using the public dataset resource ID above. Queries were restricted to the Coimbatore district and requested the latest available row for each station. The full source contains 14,643 Coimbatore-district observations at the time of retrieval; only the 21 station-level latest rows are included in this GeoJSON.

The file is suitable for a prototype map context layer and station-level review. It is not a substitute for a formally supplied, continuously updated groundwater monitoring feed or the department's authoritative station register.
