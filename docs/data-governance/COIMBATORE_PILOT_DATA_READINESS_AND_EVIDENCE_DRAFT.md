# SAMANVAY — Coimbatore Pilot Data Readiness and Evidence Draft

**Prepared:** 6 November 2026  
**Project:** SAMANVAY — Know Below. Dig Above.  
**Pilot geography:** Coimbatore district, Tamil Nadu; municipal jurisdiction must be verified per asset and road segment.  
**Purpose:** Record what public/reference datasets have actually been acquired and integrated, what remains restricted or unavailable, and what SAMANVAY can truthfully demonstrate.

## 1. Executive position

SAMANVAY now contains real, traceable public geospatial reference data for a Coimbatore pilot:

1. A 2024 Coimbatore ward-boundary reference layer containing 100 polygons.
2. A 2026–2030 Tamil Nadu groundwater telemetry snapshot containing 21 Coimbatore-district monitoring stations, with each station's latest available source observation and timestamp.

The groundwater station layer is now bundled into the Flutter app and rendered in the GIS map as a separate, switchable point layer. Users can tap a station to see its latest returned measurement and observation timestamp.

**The project still does not have authorised exact underground utility geometry.** The Supabase underground-asset registry remains separate and empty. The new groundwater telemetry points are not pipes, cables, ducts, private borewells or excavation-clearance evidence.

## 2. Datasets now in the repository

| Dataset | Source / provenance | Imported content | App integration | Important limitation |
|---|---|---:|---|---|
| Coimbatore ward boundaries (2024 reference) | OpenCity.in resource; original source recorded as livingatlas.esri.in; resource metadata marked Public Domain | 100 ward polygons | Static GeoJSON layer in MapLibre | Reference only; compare with current CCMC Gazette/official ward data before legal jurisdiction use |
| Coimbatore groundwater telemetry (2026–2030) | Tamil Nadu Surface Water and Ground Water Departments via NWDP / NWIC | 21 station points with latest available per-station measurement and timestamp | Static GeoJSON layer in MapLibre; tap marker to inspect reading/time | District-wide monitoring context; not a borewell inventory or a live feed; observation timestamps vary |
| Coimbatore district waterbody maps | Coimbatore District Administration | Official taluk-level PDF map links identified for 11 taluks | Source register only; no geometry digitised | PDFs are not a verified machine-readable GIS layer |

### 2.1 Exact repository assets

- `assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson`
- `assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson`

### 2.2 Groundwater telemetry source statistics

- NWDP resource ID: `6857c02f-c77e-4576-b349-3e45aacc1c21`
- Source period: 2026–2030
- Coimbatore district observations reported by API at retrieval: 14,643
- Distinct station records: 21
- Latest observation in the imported snapshot: 5 November 2026
- Source dataset page: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw
- Source CSV: https://nwdp.nwic.gov.in/dataset/16efa917-4b91-473b-969d-57d1bcd11924/resource/6857c02f-c77e-4576-b349-3e45aacc1c21/download/gwl_tel_6_hourly_tamil_nadu_sw_gw_tn_2026_2030.csv

The portal describes six-hourly telemetry measurements and provides station coordinates. The resource licence metadata is “Other (Open)”; the exact reuse terms should be confirmed with NWIC / the producing department before commercial redistribution. Attribution is preserved in the dataset documentation.

## 3. GIS behaviour now implemented

The MapLibre GIS screen includes:

- Coimbatore 2024 ward-reference polygons, with explicit reference-only labelling.
- Groundwater telemetry station points, independently switchable.
- Tap interaction on telemetry markers to show the station name, source measurement and source timestamp.
- Work-request locations subject to the signed-in user's Supabase access.
- Generalised underground-asset coverage for authorised staff, when aggregate records exist.
- Exact underground asset geometry only through the department-scoped verified-asset RPC; unverified geometry is withheld.
- Existing 3D basemap building extrusion is city context only. It is not a 3D model of buried pipes or cables.

## 4. Official data sources identified but not imported

| Source | Data opportunity | Current position |
|---|---|---|
| TNGIS / TNeGA | Administrative boundaries, roads, drainage context, tanks, rivers and department GIS layers | Catalogue identified. TNGIS terms restrict redistribution/publication and commercial use without approval; do not copy layers into SAMANVAY without the required permission |
| CCMC | Ward/Gazette data, road ownership, road-cutting records, UGD and stormwater asset registers | Official workflows and map references identified; current machine-readable asset datasets not supplied |
| TWAD Board | Scheme-specific water and sewer assets, as-built drawings and maintenance boundaries | Authority identified; scheme-level ownership and data-sharing approval required |
| TNPDCL | Underground distribution GIS, cable/duct and planned maintenance records | GIS entry point identified; exact data is not a public unrestricted dataset |
| PWD / WRD | Tanks, channels, canals, flood-control and water-resource assets | Public WRD portal context identified; engineer portal requires authorised access |
| Telecom and gas operators | Duct, fibre and pipeline routes | Actual operator/owner must be identified for each corridor; no authorised route dataset acquired |

## 5. What SAMANVAY can truthfully demonstrate now

- A multi-department infrastructure coordination workflow.
- A GIS map with a Coimbatore ward reference layer and public groundwater telemetry monitoring stations.
- Device GPS location and place search.
- Work-request markers from the application's own records, subject to account permissions.
- Role-scoped utility data access architecture that separates public/context data from exact owner-controlled utility geometry.
- A verified-asset import and review pathway ready for authorised datasets.

## 6. What must not be claimed

Do not claim that SAMANVAY currently has:
- A complete underground water, sewer, stormwater, electricity, gas or telecom network map.
- A complete list of private or permitted borewells.
- Live telemetry from every station.
- Current legally certified CCMC ward boundaries based only on the OpenCity 2024 reference.
- Automated excavation safety certification or statutory clearance.
- Proof that an area has no underground utilities because no records are present.

## 7. Required data-sharing route for underground utility assets

The first institutional requests should go to:

1. CCMC — ward boundaries, road inventory/ownership, road-cutting workflow, UGD and stormwater asset register.
2. TNeGA / TNGIS — current layer catalogue, metadata, permitted API/download use and written approval route.
3. TWAD — Coimbatore scheme-level water and sewer asset ownership and as-built records.
4. TNPDCL — authorised distribution GIS nodal office and approved data access.
5. Tamil Nadu Highways / NHAI — road ownership and works data for roads outside CCMC control.
6. PWD / WRD — tank, channel, canal and flood-control records.

For every imported underground asset, preserve the owner, source document, date, CRS, positional/depth accuracy, geometry type, licence/permission, verification status and survey evidence. Do not map unverified geometry as fact.

## 8. Go-live gates

- [ ] CCMC / competent authority confirms current ward and road jurisdiction for the pilot area.
- [ ] Each road segment is linked to its actual road-owning authority.
- [ ] Each underground asset is supplied or authorised by its actual owner.
- [ ] Data-sharing permission and permitted use are recorded.
- [ ] Geometry, CRS, positional accuracy, source date and update cadence are validated.
- [ ] Exact utility geometry is restricted to owner-authorised users.
- [ ] Public/requester maps never expose sensitive exact utility routes.
- [ ] Groundwater telemetry is labelled as monitoring-station data with per-station timestamps.
- [ ] Clash alerts remain advisory and are not represented as statutory excavation clearance.

## 9. Repository evidence and related records

- [Coimbatore Pilot Authority Mapping](COIMBATORE_PILOT_AUTHORITY_MAPPING.md)
- [Coimbatore Groundwater Telemetry Dataset](COIMBATORE_GROUNDWATER_TELEMETRY_DATASET.md)
- [Coimbatore Data-Sharing Request Templates](COIMBATORE_DATA_SHARING_REQUEST_TEMPLATE.md)
- [Tamil Nadu Official Data Acquisition Register](TAMIL_NADU_OFFICIAL_DATA_ACQUISITION_REGISTER.md)
- [India National Data Acquisition Register](INDIA_NATIONAL_DATA_ACQUISITION_REGISTER.md)

**Final conclusion:** SAMANVAY has progressed from an empty reference-data map to a real Coimbatore GIS prototype with two traceable spatial reference datasets and an integrated groundwater monitoring layer. It is not yet an authoritative underground-utility inventory. That final capability depends on asset-owner data-sharing approval and verified survey/as-built records.


## 10. Additional official source index committed on 6 November 2026

A machine-readable CSV source index has been committed at `data/reference/coimbatore_waterbody_map_index.csv`. It records the 11 official taluk-level PDF map links published by the Coimbatore District Administration. This adds traceable public source references, not digitised GIS features. The source page was last updated 10 August 2026. No PDF geometry has been extracted, and these documents are not underground drainage or utility records.

The project therefore has two actual spatial datasets already bundled in the app (100 ward-reference polygons and 21 groundwater telemetry station points), plus this 11-document official source index. The underground utility registry remains separate and must only receive asset-owner-approved or verified survey/as-built data.
