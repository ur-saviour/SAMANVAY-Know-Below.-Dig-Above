# SAMANVAY National Official Data Integration — India

Last verified: 2026-11-06
Scope: all 28 States and 8 Union Territories. National coverage is tracked separately from the completeness of local authority records.

## 1. Groundwater — national aggregate coverage

### 2025 national assessment
The existing SAMANVAY national assessment model contains 36 State/UT rows for assessment year 2025, linked to `public.india_state_uts`. A national summary row has also been recorded in `public.groundwater_national_summary`.

National values (2025):
- Total annual groundwater recharge: 448.52 BCM
- Annual extractable groundwater resource: 407.75 BCM
- Annual groundwater extraction: 247.22 BCM
- Stage of groundwater extraction: 60.63%
- Assessment units: 6,762
- Over-exploited: 730; Critical: 201; Semi-critical: 758; Safe: 4,946; Saline: 127

Sources:
- Ministry of Jal Shakti PIB PRID 2204095: https://www.pib.gov.in/PressReleasePage.aspx?PRID=2204095&lang=1&reg=3
- Official 2025 national compilation: https://www.jalshakti-dowr.gov.in/static/uploads/2025/11/711d8d476bbf498cd90f8038e7371227.pdf
- CGWB publication page: https://cgwb.gov.in/en/national-compilation-dynamic-ground-water-resources-india-2025

The assessment table already held detailed state/UT rows. Duplicate rows created during source normalization were removed; existing rows and their more detailed fields were preserved. The new national summary is stored separately.

### Monitoring station time series — partial national coverage
Database verification found:
- 304,123 groundwater station observations.
- 30 distinct States/UTs represented.
- 70 districts and 137 distinct station names.
- Observation dates range from 2022-08-28 to 2025-12-31.
- Source records point to NWIC/CGWB hourly telemetry resource pages.

Important completeness caveat: six jurisdictions currently have no station observations in the table: Andaman and Nicobar Islands, Dadra and Nagar Haveli and Daman and Diu, Ladakh, Lakshadweep, Puducherry and Sikkim. Several resource groups contain exactly 5,000 rows, indicating likely resource/page import caps; 304,123 rows must not be represented as the complete national telemetry archive. The import-run audit table currently has no corresponding completed run records. The existing observations are retained, but resource-by-resource reconciliation and audit logging remain necessary.

Official source catalogue:
- Hourly telemetry: https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-hourly-central-ground-water-board-cgwb
- Six-hourly telemetry and quarterly manual measurements: https://nwdp.nwic.gov.in/dataset/?groups=water-quantity&organization=cgwb
- Groundwater quality datasets: https://nwdp.nwic.gov.in/

## 2. Utility GIS — national layer contracts and source programmes registered

National GIS reference programmes:
- NRSC/ISRO AMRUT urban GIS: base maps prepared for 238 cities across 20 States/UTs; NRSC reports 181 GIS databases finalized/delivered to ULBs.
- National Urban Information System (NUIS): 1:10,000 urban geospatial databases for 152 towns.
- Source: https://www.nrsc.gov.in/nrscnew/Apps_Urban_Apps.php?lang_code=en

National layer contracts are registered in `gis.utility_layer_catalog` for:
- City water distribution networks
- Sewerage/underground drainage networks
- Stormwater drainage networks
- Urban base maps

The national contracts do not prove that asset data has been received. Urban base maps are not utility pipe alignments. Operational-use flags remain disabled until the relevant authority provides asset-level geometry and required attributes.

Still required from state water boards, sewerage boards, development authorities and ULBs: pipe alignments, manholes, diameters, depths, invert levels, asset IDs, commissioning/status fields, positional accuracy, metadata and written permission for operational use. Coverage will vary by jurisdiction.

## 3. Building approvals — national framework registered; local records pending

National integration references:
- MoHUA / National Urban Digital Mission UPYOG Building Plan Approval reference application: https://www.nudm.mohua.gov.in/building-plan-approval/
- National Government Services Portal: https://services.india.gov.in/
- State/ULB portals such as CCMC AutoDCR are registered as jurisdiction-specific sources.

UPYOG is a shared urban governance platform/reference application, not a single consolidated nationwide public approval register. Actual deployments, APIs, access rights and record publication vary by state and ULB.

The table `public.building_approval_records` is prepared for state, district and ULB-scoped approvals, including approval number/date/status, locality/ward/survey reference, approved floors/height, portal and verification status. Current imported record count is zero. No approval numbers, property identifiers or permitted floors have been fabricated.

## 4. Data provenance and operational rules

- Each record must carry source agency, source URL/reference, jurisdiction and observation/approval date where available.
- Distinguish national/state aggregate data from district/block/ward/asset-level data.
- Distinguish reference base maps from verified utility network geometry.
- Distinguish a building application from an issued approval and an issued approval from a field-verified building.
- Restricted departmental data must not be scraped, bypassed or treated as public. Use formal authority exports/API access or authorized portal access.
- Do not use inferred underground routes for excavation clearance.

## 5. Database state verified in this run

- `public.india_state_uts`: 36 jurisdiction master records.
- `public.groundwater_state_assessments`: 36 existing 2025 State/UT aggregate rows (duplicates from source normalization removed).
- `public.groundwater_national_summary`: 1 imported 2025 national summary.
- `public.groundwater_station_observations`: 304,123 existing records across 30 States/UTs, 70 districts and 137 station names; partial, not a complete national archive.
- `public.groundwater_data_import_runs`: 0 audit records.
- `public.official_data_sources`: 30 source records.
- `gis.utility_layer_catalog`: 116 rows total in the existing catalog, including national utility layer contracts; row count does not imply received or verified geometries.
- `public.building_approval_records`: 0 imported approval records.

## 6. Completion status

Completed: national jurisdiction master coverage, 2025 national groundwater summary, all 36 State/UT groundwater aggregate records verified, existing partial telemetry archive quantified, national official-source registry expansion, national utility layer contracts, and database security/provenance structure.

Not completed: reconciliation and completion of groundwater station time series for all jurisdictions, asset-level utility GIS from participating authorities, and jurisdiction-specific building approval records. These require resource-level ingestion and/or authorized state/ULB data access. Do not label these operational datasets complete until records are actually imported and validated.
