# SAMANVAY Official Data Integration — Coimbatore Pilot

Last verified: 2026-11-06

## Groundwater

### Imported and verified
- One district-level assessment record for Coimbatore, Tamil Nadu, assessment year 2024.
- Source: Government of India / Central Water Commission annexure to Lok Sabha Unstarred Question No. 1388, "District-wise Dynamic Ground Water Resources of Tamil Nadu, 2024".
- Source URL: https://www.cwc.gov.in/sites/default/files/usq-1388-merge.pdf
- Values imported (Ham): total annual recharge 60,383.89; annual extractable groundwater resource 54,421.92; annual groundwater extraction 47,180.46; stage of extraction 86.69%.
- Stored in `public.groundwater_resource_assessments` with source reference and source document URL.

### Not yet imported
- NWDP Tamil Nadu six-hourly telemetry CSV/API is a verified official source. Dataset page: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw
- The dataset page advertises CSV/API resources, but the direct CSV download could not be fetched by the integration environment during this run.
- `public.groundwater_station_observations` remains empty; do not represent the 14,643-record source preview/count as imported database rows.
- Importer/run tables already exist. Complete the actual bulk sync only after a successful CSV/API fetch and schema mapping validation.

## CCMC / TWAD utility GIS

### Registered integration targets
- CCMC Water Supply: https://ccmc.gov.in/index.php/department/water-supply
- CCMC Online Plan Approval/AutoDCR reference: https://www.ccmc.gov.in/index.php/createpage/online-plan-approval
- CCMC UGD: https://www.ccmc.gov.in/index.php/department/ugd
- TWAD Board: https://www.twadboard.tn.gov.in/

### GIS catalogue
The following layer contracts are registered in `gis.utility_layer_catalog`:
- CCMC potable-water distribution
- CCMC underground drainage/sewerage
- TWAD water-supply schemes
- CCMC stormwater drainage

Each layer records its expected geometry/attributes, authority, accuracy requirement and operational-use flag. All four are explicitly marked `authority_data_pending`; operational use is disabled.

### Data limitation
No authoritative Coimbatore asset-level pipe/sewer/stormwater geometry, manhole inventory, invert levels, commissioning metadata or survey accuracy records were obtained in this integration run. Public department pages establish institutional responsibility, not the location of underground assets. Do not use ward polygons, waterbodies, road lines or schematic features as utility clearance data.

## Building approvals

### Registered official portals
- CCMC AutoDCR / online plan approval: https://www.ccmc.gov.in/index.php/createpage/online-plan-approval
- Tamil Nadu CMA Building Plan Approval Search: https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx

CCMC describes AutoDCR as the workflow used to process and store building plan applications and approvals. The CMA portal exposes a public search interface, but no reliable bulk Coimbatore export/API was identified in this run.

### Database
- `public.building_approval_records` is created with approval reference, approval date/status, locality/ward/survey references, approved floor count/height, official record URL and verification state.
- It currently contains zero records. No fabricated approvals or applicant details have been inserted.
- The separate `public.building_compliance_inspections` workflow remains for field inspections and should not be conflated with the authority's original approval register.

## Database changes applied

- `public.official_data_sources`: source register with agency, source URL, access mode and integration status.
- `public.groundwater_resource_assessments`: district-level resource assessment facts and provenance.
- `gis.utility_layer_catalog`: utility layer contracts and data-readiness state.
- `public.building_approval_records`: authority approval register schema.
- Row-level security enabled on all four tables. Authenticated users can read the source register, groundwater assessments and utility catalogue. Approval records are restricted to admin/coordinator roles. Administrative writes are restricted to admin/coordinator profiles.

## Verified database state at 2026-11-06

| Dataset/table | Rows | State |
|---|---:|---|
| `groundwater_resource_assessments` | 1 | Coimbatore 2024 district assessment imported |
| `groundwater_station_observations` | 0 | NWDP telemetry import pending |
| `gis.utility_layer_catalog` | 4 | Layer contracts registered; authority geometry pending |
| `building_approval_records` | 0 | Schema ready; official approval records pending |
| `official_data_sources` | 6 | Official/public sources registered |

## Operational rule

Only records with traceable source provenance and appropriate verification may be displayed as official or operationally reliable. Until CCMC/TWAD supplies authoritative GIS files and the approval authority provides a usable export or verified individual records, those layers must remain visibly unavailable/pending. Never infer underground routes, depth, manholes, permitted floors or approval status from unrelated public maps.
