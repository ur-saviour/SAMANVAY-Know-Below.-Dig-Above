# SAMANVAY National Official Data Integration — India

Last verified: 2026-11-06
Scope: all 28 States and 8 Union Territories. National coverage is tracked separately from the completeness of local authority records.

## 1. Groundwater — national aggregate import completed

### 2025 national assessment
Imported the latest published 2025 Dynamic Ground Water Resources Assessment into:
- `public.groundwater_national_summary`: one national summary row.
- `public.groundwater_state_assessments`: 36 state/UT aggregate rows, linked to the existing `public.india_state_uts` master table.

National values (2025):
- Total annual groundwater recharge: 448.52 BCM
- Annual extractable groundwater resource: 407.75 BCM
- Annual groundwater extraction: 247.22 BCM
- Stage of groundwater extraction: 60.63%
- Assessment units: 6,762
- Over-exploited: 730; Critical: 201; Semi-critical: 758; Safe: 4,946; Saline: 127

All 36 State/UT aggregates are imported with the official Ministry of Jal Shakti parliamentary annexure source URL and source reference. Source: PIB Ministry of Jal Shakti PRID 2204095 and CGWB 2025 national compilation:
- https://www.pib.gov.in/PressReleasePage.aspx?PRID=2204095&lang=1&reg=3
- https://www.jalshakti-dowr.gov.in/static/uploads/2025/11/711d8d476bbf498cd90f8038e7371227.pdf
- https://cgwb.gov.in/en/national-compilation-dynamic-ground-water-resources-india-2025

### Monitoring station time series — pending bulk import
Official NWIC/CGWB datasets identified:
- Hourly telemetry: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-hourly-central-ground-water-board-cgwb
- Six-hourly telemetry and quarterly manual measurements: https://nwdp.nwic.gov.in/dataset/?groups=water-quantity&organization=cgwb
- Groundwater quality datasets: https://nwdp.nwic.gov.in/

These contain station/time-series data and are distinct from the annual resource assessment. Station observation import is not yet complete. The source catalogue is registered; direct CSV/API resources must be fetched, schema-validated, deduplicated and imported by state/resource.

## 2. Utility GIS — national layer contracts and source programmes registered

National GIS reference programmes identified:
- NRSC/ISRO AMRUT urban GIS: base maps prepared for 238 cities across 20 States/UTs; NRSC reports 181 GIS databases finalized/delivered to ULBs.
- National Urban Information System (NUIS): 1:10,000 urban geospatial databases for 152 towns.
- Source: https://www.nrsc.gov.in/nrscnew/Apps_Urban_Apps.php?lang_code=en

National layer contracts are registered in `gis.utility_layer_catalog` for:
- City water distribution networks
- Sewerage/underground drainage networks
- Stormwater drainage networks
- Urban base maps

The four national contracts are not proof that asset data has been received. Urban base maps are not utility pipe alignments. The operational-use flags remain disabled until the relevant authority provides asset-level geometry and required attributes.

Still required from state water boards, sewerage boards, development authorities and ULBs: pipe alignments, manholes, diameters, depths, invert levels, asset IDs, commissioning/status fields, positional accuracy, metadata and written permission for operational use. Data coverage will vary by jurisdiction.

## 3. Building approvals — national framework registered; local records pending

National integration references:
- MoHUA / National Urban Digital Mission UPYOG Building Plan Approval reference application: https://www.nudm.mohua.gov.in/building-plan-approval/
- National Government Services Portal: https://services.india.gov.in/
- State/ULB portals such as CCMC AutoDCR are registered as jurisdiction-specific sources.

UPYOG is a shared urban governance platform/reference application, not a single consolidated nationwide public approval register. Actual deployments, APIs, access rights and record publication vary by state and ULB.

The table `public.building_approval_records` is prepared for state, district and ULB-scoped approvals, including approval number/date/status, locality/ward/survey reference, approved floors/height, portal and verification status. Current imported record count is zero. No approval numbers, property identifiers or permitted floors have been fabricated.

## 4. Utility and approval data provenance rules

- Each record must carry a source agency, source URL/reference, jurisdiction and observation/approval date where available.
- Distinguish national/state aggregate data from district/block/ward/asset-level data.
- Distinguish reference base maps from verified utility network geometry.
- Distinguish a building application from an issued approval and an issued approval from a field-verified building.
- Restricted departmental data must not be scraped, bypassed or treated as public. Use formal authority exports/API access or authorized portal access.
- Do not use inferred underground routes for excavation clearance.

## 5. Database state verified in this run

- `public.india_state_uts`: 36 jurisdiction master records.
- `public.groundwater_state_assessments`: 36 imported 2025 State/UT aggregate rows.
- `public.groundwater_national_summary`: 1 imported 2025 national summary.
- `public.official_data_sources`: 30 source records in the register.
- `gis.utility_layer_catalog`: 116 rows total in the existing catalog, including the national utility layer contracts; row count does not imply received or verified geometries.
- `public.building_approval_records`: 0 imported approval records.
- Groundwater station time-series import: pending; a successful bulk sync has not been verified.

## 6. Completion status

Completed: national jurisdiction master coverage, 2025 national groundwater summary, 36 State/UT groundwater aggregate imports, national official-source registry expansion, national utility layer contracts, and database security/provenance structure.

Not completed: station-level groundwater time series, asset-level utility GIS from every participating authority, and jurisdiction-specific building approval records. These require resource downloads and/or authorized state/ULB data access. Do not label these three operational datasets complete until records are actually imported and validated.
