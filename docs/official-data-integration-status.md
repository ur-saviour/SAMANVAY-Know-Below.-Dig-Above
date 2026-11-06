# SAMANVAY National Official Data Integration — India

Last verified: 2026-11-06
Scope: all 28 States and 8 Union Territories. National coverage is tracked separately from the completeness of local authority records.

## Executive status

- National jurisdiction master: all 36 States/UTs.
- CGWB 2025 groundwater resource assessment: 36/36 State/UT aggregate records imported.
- NWDP/CGWB 2021-2025 telemetry: 1,095,209 observations currently stored at latest check; 10 resource feeds complete, 22 partial, 30 discovered/not yet imported. The advertised source-row sum is 16,528,153 across 62 resource records at latest check; alternative/agency feeds can overlap, so this is not a deduplicated national count.
- Additional 199 district-level groundwater rows from seven State/UT CSV mirrors are stored in a separate reconciliation staging table; they are not cleared for official aggregation.
- Utility GIS: 108 State/UT layer contracts plus 8 original Coimbatore pilot records (116 total); 115 are authority-data-pending and zero are enabled for operational excavation use.
- Building approvals: 25 State/UT jurisdictions have an official portal or service-directory URL mapped; 11 still need an authority/ULB portal mapping. The approvals table contains zero imported approval records.

## 1. Groundwater

### National resource assessment — complete at State/UT aggregate level

Source: Central Ground Water Board (CGWB), Ministry of Jal Shakti, National Compilation on Dynamic Ground Water Resources of India, 2025.

- Official report: https://www.jalshakti-dowr.gov.in/static/uploads/2025/11/711d8d476bbf498cd90f8038e7371227.pdf
- CGWB publication page: https://cgwb.gov.in/en/national-compilation-dynamic-ground-water-resources-india-2025
- Ministry of Jal Shakti PIB release: https://www.pib.gov.in/PressReleasePage.aspx?PRID=2204095&lang=1&reg=3

The database contains 36 State/UT rows for assessment year 2025 in public.groundwater_state_assessments, linked to public.india_state_uts. The report's national summary is separately represented in public.groundwater_national_summary.

National report values:
- Total annual groundwater recharge: 448.52 BCM.
- Annual extractable groundwater resource: 407.75 BCM.
- Annual groundwater extraction: 247.22 BCM.
- Stage of extraction: 60.63%.
- Assessment units: 6,762.
- Over-exploited: 730; Critical: 201; Semi-critical: 758; Safe: 4,946; Saline: 127.

The assessment was prepared jointly by CGWB and State/UT agencies. State/UT aggregate records are suitable for national comparative context; they are not live groundwater-level readings and do not replace block/assessment-unit classification or station time series.

### NWDP/CGWB station telemetry — real nationwide data, partial import

Official NWDP CKAN API and dataset pages:
- Hourly telemetry: https://www.nwdp.nwic.gov.in/dataset/ground-water-level-telemetry-hourly-central-ground-water-board-cgwb
- Six-hourly telemetry and manual quarterly groundwater monitoring: https://nwdp.nwic.gov.in/

Current-period (2021-2025) resources catalogued:
- 62 resource records.
- Sum of advertised source row counts: 16,528,153 across those resource records at latest check. Some are alternative/agency feeds for a jurisdiction; this is not a deduplicated unique-observation count.
- 10 resources completed, 22 partially imported, 30 discovered/not yet imported. Live DB recheck: 420,209 rows in completed resources and 675,000 rows in partial resources (1,095,209 observation rows overall). A resumable GitHub Actions import run was started on 2026-11-06 and is still processing the backlog.
- 1,095,209 station observations currently stored in public.groundwater_station_observations.
- Observations currently represent 31 State/UT labels, 331 distinct station-name labels and 158 district-name labels.

The ten resources currently complete are (420,209 rows in total; 675,000 additional rows are imported from 22 partial resources):
- Assam — 160,859 rows.
- Bihar — 52,998.
- Jharkhand — 39,519.
- Meghalaya — 36,117.
- Manipur — 35,797.
- Uttarakhand — 30,422.
- Himachal Pradesh — 28,353.
- Tripura — 19,465.
- Arunachal Pradesh — 13,415.
- Nagaland — 3,264.

All other current-period resources retain their next_offset and import state in public.groundwater_source_resources. Five jurisdictions have no 2021-2025 resource identified in the current public NWDP search: Andaman and Nicobar Islands, Dadra and Nagar Haveli and Daman and Diu, Ladakh, Lakshadweep and Sikkim. This is a catalogue search result, not evidence that no groundwater monitoring is performed there.

### Resumable ingestion implementation

- Database function: public.import_nwdp_telemetry_page(resource_id, offset, limit).
- It obtains records from the public NWDP CKAN API, maps station, State/District LGD codes, coordinates, acquisition time and water-level columns, then performs an idempotent upsert with a source-resource checkpoint.
- GitHub runner: scripts/import_nwdp_telemetry.py.
- GitHub Actions workflow: .github/workflows/import-nwdp-groundwater.yml.
- The runner reuses the existing GitHub secrets SUPABASE_DB_HOST, SUPABASE_PROJECT_REF and SUPABASE_DB_PASSWORD; it commits after each page so interrupted runs can resume.
- The workflow is on feature/alpha-03-integrated-platform. It must be merged into the repository's default branch before standard workflow-dispatch access is available there.

### District groundwater source extracts — staged, not aggregate-reconciled

A public OpenCity CKAN mirror of CGWB-attributed 2025 district CSV extracts was identified for Delhi, Goa, Gujarat, Karnataka, Maharashtra, Tamil Nadu and Telangana:
https://data.opencity.in/dataset/3e28a58b-22d4-4f6a-89ac-9738693eb745

- 199 rows stored in public.groundwater_district_assessments across seven jurisdictions and 189 distinct district labels.
- Resource identifiers, mirror URLs, official CGWB report URL and source-record identifiers are retained.
- The source row values are held in a separate staging table with row_crosschecked_not_aggregated validation.
- Sample rows were compared with the corresponding CGWB report annexure. However, district sums do not reconcile to the State/UT Annexure I totals and the mirror's numeric unit labelling is inconsistent. The rows are therefore marked source_report_scale_unreconciled and must not be summed into or presented as validated official State totals.
- Full district/block classification imports from the CGWB report remain pending for the other jurisdictions and require reconciliation.

## 2. Utility GIS — India-wide schema and authority coverage

National geospatial coordination reference:
- PM GatiShakti National Master Plan: https://staging1.pmgatishakti.gov.in/pmgatishakti/about_pmgati

PM GatiShakti is a controlled, whole-of-government integration programme; it is not treated as a public downloadable national underground-pipe database.

Current schema:
- public.india_data_coverage: one utility GIS coverage record for every State/UT.
- gis.utility_layer_catalog: 116 layer contracts in total, including 108 State/UT-specific contracts (water distribution, sewerage and stormwater for each of 36 jurisdictions) and the original Coimbatore pilot catalogue.
- 115 entries are marked authority-data-pending; zero entries are enabled for operational use.

Each layer contract defines expected feature geometry and fields such as asset ID, owner authority, material/type, diameter, depth, invert level, manhole/outfall reference, operational state, commissioning date and horizontal/vertical survey accuracy.

No claim of national asset geometry completion is made. No authoritative all-India State/UT/ULB utility network export has been obtained. State water boards, municipal corporations, sewerage boards and local bodies hold different network datasets. For live excavation safety, require the owning authority's data, coordinate reference system, survey accuracy, depth datum, revision date and permission to use it. Roads, wards, waterbodies, schematic lines and satellite imagery are not substitutes for underground asset geometry.

CCMC's public UGD source provides departmental/project context but not the complete current pipe/manhole GIS required for operational clearance.

## 3. Building approvals — national portal mapping, authority records pending

National reference:
- MoHUA / National Urban Digital Mission UPYOG Building Plan Approval: https://www.nudm.mohua.gov.in/building-plan-approval/
- National Government Services Portal: https://services.india.gov.in/

The 36-jurisdiction coverage matrix currently has 25 State/UT rows with a mapped official portal or service-directory entrypoint. Eleven jurisdictions still have no portal URL mapped: Arunachal Pradesh, Chandigarh, Himachal Pradesh, Lakshadweep, Manipur, Meghalaya, Mizoram, Nagaland, Puducherry, Tripura and Uttarakhand.

Examples of official portal references registered:
- Andhra Pradesh — APDPMS 2.0: https://portal.apdpms.ap.gov.in/
- Assam — OBPS: https://eservices.assam.gov.in/resources/homePage/18/obps/index.html
- Bihar — UPYOG building plan service: https://upyog.bihar.gov.in/c/services/building-plan
- Goa — BPAMS: https://www.bpams.goa.gov.in/
- Gujarat — GIDC plan approval (GIDC estates only): https://www.gidc.gujarat.gov.in/Pages/Contents/application-for-plan-approval
- Haryana — ULB OBPAS: https://obpas.ulbharyana.gov.in/
- Jammu and Kashmir — OBPS: https://obps.jk.gov.in/BPAMSClient/Home.aspx
- Jharkhand — JIADA building plan service (JIADA industrial areas only): https://jiada.jharkhand.gov.in/
- Karnataka — Government Services Portal listing: https://services.india.gov.in/service/detail/land-and-building-plan-approval-system-karnataka
- Kerala — K-SMART / LSGD building permits: https://lsgd.kerala.gov.in/en/apply-for-building-permits/
- Ladakh — building plan approval: https://eodb.ladakh.gov.in/approvals/building-plan-approval
- Madhya Pradesh — ABPAS 3.0: https://abpas.mpurban.gov.in/
- Maharashtra — AutoDCR (participating authorities; not assumed statewide): https://maha.autodcr.com/BPAMSClient/Default.aspx
- Odisha — GO SWIFT: https://investodisha.gov.in/GOSWIFT/
- Punjab — eNaksha: https://enaksha.lgpunjab.gov.in/
- Rajasthan — UDH online services: https://lsg.urban.rajasthan.gov.in/content/raj/udh/udh-department/en/udh-online-services.html
- Sikkim — SSO service directory lists Online Building Permission System: https://sso.sikkim.gov.in/services
- Tamil Nadu — Single Window Planning Permission: https://onlineppa.tn.gov.in/
- Telangana — BuildNow: https://buildnow.telangana.gov.in/
- Uttar Pradesh — UPOBPAS: https://upobpas.in/BPAMSClient/Home.aspx (the source portal records suspension of new submissions in 2026; do not assume it is the current active new-application channel)
- West Bengal — e-Grihanaksha/OBPAS: https://obpsudma.wb.gov.in/
- Andaman and Nicobar — ANI e-Seva listing: https://anieseva.andamannicobar.gov.in/services_list_depart1.php?id=MjE%3D
- Dadra and Nagar Haveli — DNH Planning and Development Authority: https://www.dnhpda.in/wf/
- Daman and Diu — UT single window (Diu construction-permission scope): https://swp.dddgov.in/

Important limitations: portal URLs do not imply statewide municipal coverage, public bulk downloads, or API access. Some entries are a service directory or apply only to an industrial authority/participating ULB. The 25 is a portal-mapping count, not a count of complete State/UT approval registers.

Database:
- public.building_approval_records stores State, district, ULB, approval reference, date/status, ward, survey/plot reference, sanctioned floors/height, source document and verification state.
- Verified imported approval rows: 0. No approval numbers, applicant records, parcel IDs or permitted floors have been invented.
- Actual approvals must be imported from authority-provided exports/API or individually accessible, public records with their provenance. Application status is not equivalent to approval; an approval is not equivalent to an occupancy certificate or field verification.

## 4. Database objects and security

- public.india_state_uts: 36 States/UTs.
- public.india_data_coverage: 108 rows (36 jurisdictions × 3 data domains), including telemetry progress fields.
- public.official_data_sources: 49 source entries.
- public.groundwater_state_assessments: 36 official 2025 State/UT aggregate records.
- public.groundwater_national_summary: one national summary row.
- public.groundwater_source_resources: 62 current-period telemetry resources plus other historical/forward resources.
- public.groundwater_station_observations: 850,209 imported telemetry rows.
- public.groundwater_district_source_resources: seven mirrored district CSV resources and provenance.
- public.groundwater_district_assessments: 199 district rows, reconciliation pending.
- gis.utility_layer_catalog: 116 utility layer contracts; zero operationally enabled.
- public.building_approval_records: India-ready approval register; zero imported approvals.

Row-level security is enabled for new exposed tables. Read access is authenticated where appropriate; administrative changes are limited to admin/coordinator profiles. The telemetry page importer and district staging importer are revoked from public, anon and authenticated roles; they are invoked through privileged ingestion.

## 5. Verified national data state at 2026-11-06

| Dataset | Rows | Meaning |
|---|---:|---|
| State/UT jurisdiction master | 36 | 28 States + 8 UTs |
| 2025 CGWB State/UT resource assessments | 36 | Imported aggregate assessment rows |
| 2025 CGWB national summary | 1 | National summary |
| NWDP/CGWB telemetry observations | 850,209 | Real records; partial across 31 State/UT labels |
| Current-period telemetry resources | 62 | 10 complete, 21 partial, 31 not yet imported |
| Advertised source rows across 62 resources | 14,249,309 | Sum across resources; not a unique/deduplicated national count |
| 2025 district groundwater staging rows | 199 | Seven jurisdictions; reconciliation pending |
| National coverage matrix | 108 | 36 × groundwater, utility GIS, building approvals |
| Utility layer contracts | 116 | 115 pending authority data; zero operational |
| Building approval portal/service URLs | 25 | 11 jurisdictions still need portal mapping |
| Verified building approval records | 0 | Authority records not imported |
| Registered data source entries | 49 | National/State/UT/ULB and reference sources |

## 6. Remaining completion work

1. Run the GitHub Actions NWDP importer from the repository's default branch and continue until all source resources have reached their recorded total. Investigate the five State/UTs with no matching 2021-2025 telemetry resource in the current public search; add other official groundwater department feeds where available.
2. Import CGWB district/assessment-unit data nationally from the official report tables or official files; reconcile units and State totals before promoting district rows to trusted analytical tables.
3. Obtain State/UT/ULB utility GIS files and the related rights/metadata from each network owner. Validate coordinate reference system, depth/invert datum, positional accuracy and update date before enabling a layer.
4. Finish mapping all 36 jurisdictions' municipal/development authority building approval portals. Obtain authority exports/API/data-sharing permission and import verified approval records with provenance.
5. Maintain a distinction in the app UI between: source registered, file retrieved, rows imported, row-level validated, aggregate reconciled, and authority/field verified.

## Operational rule

National source discovery, schema coverage and partial data ingestion are not the same as a fully populated operational national registry. Only source-proven, appropriately validated records may be described as authoritative. Pending utility layers must not be used for excavation clearance. Never infer underground route, depth, manhole position, permit status or permitted building floors from unrelated public maps or imagery.

## 4. India-wide application interface update — 6 November 2026

- The Flutter groundwater dashboard now selects from the 36-row State/UT directory and loads the selected jurisdiction's CGWB 2025 resource assessment separately from station observations.
- The GIS groundwater overlay now queries the nationwide latest-station view. Latest database check: 382 mapped station points across 31 represented State/UT labels and 158 district labels.
- A national readiness panel summarizes the three data domains (groundwater, utility GIS and building approvals) without equating portal discovery with imported records.
- The browser operations portal compiled successfully in GitHub Actions; its packaged artifact is attached to run 42249149103.
- The Android APK workflow has passed Dart analysis and is in the release APK build stage at the time of this update.
- Remaining external dependencies are unchanged: authority-supplied utility network GIS, official building approval exports, final survey verification, and any API credentials required for optional third-party services.
