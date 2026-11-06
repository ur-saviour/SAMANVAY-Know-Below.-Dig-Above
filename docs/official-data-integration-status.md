# SAMANVAY India-Wide Official Data Integration

Last verified: 2026-11-06

## Scope

This implementation is India-wide: all 28 States and 8 Union Territories are represented in the jurisdiction master and coverage matrix. The database now distinguishes nationally published datasets, State/UT records, and local utility / building approval records. A portal or schema being registered is not the same as the underlying operational records being imported.

## 1. Groundwater

### National assessment imported

Source: Central Ground Water Board, Ministry of Jal Shakti, *National Compilation on Dynamic Ground Water Resources of India, 2025*.

Official PDF:
https://www.jalshakti-dowr.gov.in/static/uploads/2025/11/711d8d476bbf498cd90f8038e7371227.pdf

CGWB publication page:
https://cgwb.gov.in/en/national-compilation-dynamic-ground-water-resources-india-2025

The 2025 State/UT Annexure I has been imported into `public.groundwater_state_assessments`:
- 36 State/UT rows imported (28 States + 8 Union Territories).
- Each row includes seasonal recharge, total annual recharge, natural discharge, extractable resource, irrigation/industrial/domestic extraction, total extraction, future-use availability and stage of extraction.
- Units retained from the source: BCM.
- Source document URL and report/annexure provenance are stored on every row.

The report gives national totals of 448.52 BCM annual recharge, 407.75 BCM annual extractable groundwater resource, 247.22 BCM annual extraction and 60.63% stage of extraction. Individual State/UT rows are rounded, so their sums can differ by 0.01 BCM from the report's national totals. The report itself notes rounding discrepancies.

### Groundwater monitoring stations — not yet imported

Official NWDP/CGWB datasets have been identified:
- Hourly telemetry: https://www.nwdp.nwic.gov.in/dataset/ground-water-level-telemetry-hourly-central-ground-water-board-cgwb
- Six-hourly telemetry: https://nwdp.nwic.gov.in/dataset/ground-water-level-telemetry-daily-cgwb-as-assam
- Manual quarterly monitoring: https://nwdp.nwic.gov.in/dataset/gwl-manual-quarterly-central-ground-water-board-department

The portal publishes CSV/API resources with station identifiers, timestamps, geographic hierarchy and water-level measurements. This run did not complete a successful bulk CSV transfer, so `public.groundwater_station_observations` remains empty. Do not describe any portal preview count as imported database rows.

### Assessment granularity still pending

The 2025 report contains district-wise (Annexure II) and assessment-unit categorisation tables. The current successful import is the State/UT aggregate layer; district/block assessment ingestion and station time-series import remain separate tasks.

## 2. Utility GIS — all India

### National spatial integration references

PM GatiShakti National Master Plan:
https://staging1.pmgatishakti.gov.in/pmgatishakti/about_pmgati

PM GatiShakti describes whole-of-government integration of infrastructure and socio-economic GIS across 36 States/UTs. Its access is controlled; it is not treated as a public downloadable underground utility database.

### Database catalogue

- `public.india_state_uts`: all 36 jurisdictions.
- `public.india_data_coverage`: utility GIS coverage row for every State/UT.
- `gis.utility_layer_catalog`: water distribution, sewerage and stormwater layer contracts for every State/UT, plus the original Coimbatore pilot layer records.

National layer contracts define expected geometry and attributes such as asset ID, owner authority, pipe/drain type, diameter, depth, invert level, manhole/outfall reference, operational state and horizontal/vertical survey accuracy.

**Operational limitation:** The national catalogue entries are authority-data-pending and operational use is disabled. No nationwide authoritative utility geometry set was imported. State departments, water boards, sewerage boards and ULBs maintain separate source systems; a central GIS platform does not itself establish public access or prove pipe positions. Never treat schematic networks, roads, wards or surface waterbody boundaries as underground utility clearance data.

## 3. Building approvals — all India

### National service architecture

MoHUA / National Urban Digital Mission — UPYOG Building Plan Approval:
https://www.nudm.mohua.gov.in/building-plan-approval/

The national UPYOG reference application describes a common digital-service model, but actual approval registers are still held by State/UT departments, development authorities and ULBs.

### Verified official portal examples registered

- Tamil Nadu: https://onlineppa.tn.gov.in/
- Telangana: https://buildnow.telangana.gov.in/
- Haryana: https://obpas.ulbharyana.gov.in/
- West Bengal: https://obpsudma.wb.gov.in/
- Odisha: https://investodisha.gov.in/GOSWIFT/
- Bihar: https://upyog.bihar.gov.in/c/services/building-plan
- Delhi (MCD jurisdiction): https://eodb.mcd.gov.in/
- Karnataka service listing: https://services.india.gov.in/service/detail/land-and-building-plan-approval-system-karnataka
- Maharashtra (MIDC jurisdiction only): https://midc.maharashtra.gov.in/en/customers/

These entries identify portals only; they do not imply that every municipal body in those jurisdictions uses that portal, nor that public bulk exports are available. Delhi MCD and Maharashtra MIDC links are explicitly limited in jurisdiction. Remaining State/UT portal mapping is pending.

### Database

`public.building_approval_records` is an India-ready approval register with issuing authority, State, district, ULB, approval reference/date/status, ward/plot/survey reference, sanctioned floors/height, source document and verification status. It contains no fabricated approval rows. Current imported approval-record count is zero.

## Database changes applied

- `public.india_state_uts`: 36 jurisdictions.
- `public.groundwater_state_assessments`: 36 imported official State/UT 2025 assessment records.
- `public.india_data_coverage`: 108 rows — one groundwater, one utility GIS and one building-approval coverage row per jurisdiction.
- `gis.utility_layer_catalog`: India-wide layer contracts for water distribution, sewerage and stormwater by State/UT, alongside the earlier Coimbatore pilot catalogue.
- `public.official_data_sources`: central national datasets and verified State/UT building-plan portal references registered.
- `public.building_approval_records`: expanded with State/district/ULB/ward/plot and approval-document fields.
- RLS is enabled on the new exposed tables. Reads are authenticated; administrative data management is restricted to admin/coordinator roles. Building approval records are restricted to admin/coordinator roles.

## Verified database state at 2026-11-06

| Dataset/table | Rows | Meaning |
|---|---:|---|
| `india_state_uts` | 36 | 28 States + 8 UTs |
| `groundwater_state_assessments` | 36 | Official 2025 State/UT groundwater assessment imported |
| `groundwater_station_observations` | 0 | NWDP station telemetry not transferred yet |
| `india_data_coverage` | 108 | Coverage/status rows across 36 jurisdictions x 3 data domains |
| `gis.utility_layer_catalog` | 112 | 108 State/UT layer contracts + 4 original Coimbatore pilot layers |
| `building_approval_records` | 0 | Nationwide register schema ready; authority records pending |
| `official_data_sources` | 21 | National sources and State/UT portal references |

## Remaining work before claiming full nationwide data completion

1. Transfer and validate NWDP hourly/six-hourly and manual quarterly station CSV/API records, then bulk load station observations.
2. Import district and assessment-unit groundwater detail from CGWB Annexure II / categorisation tables, with stable State/District/Block identifiers.
3. Obtain authoritative utility GIS exports and metadata from each State/UT utility owner and ULB; validate CRS, survey accuracy, depth datum and operational dates before enabling map use.
4. Obtain official building-approval exports/API access per State/UT authority and ULB; import only source-verifiable approvals and preserve the issuing authority's scope.

## Operational rule

National coverage is not a claim of national completeness. Only data with traceable source provenance and sufficient spatial/record verification may be presented as authoritative or safe for operational decisions. Pending layers must remain visibly pending, and no approval or underground asset location may be inferred or fabricated.
