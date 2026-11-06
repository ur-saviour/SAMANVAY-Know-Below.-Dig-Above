# Tamil Nadu government data source register — SAMANVAY

Last reviewed: 6 November 2026

## 1. Groundwater telemetry — importable public dataset

**Source:** National Water Data Portal (NWDP), National Water Informatics Centre, Ministry of Jal Shakti.  
**Producer:** Tamil Nadu Surface Water and Ground Water Departments (Tamil Nadu SW GW).  
**Resource:** Ground Water Level (Telemetry — Six Hourly), Tamil Nadu, 2026–2030.  
**Resource ID:** 6857c02f-c77e-4576-b349-3e45aacc1c21  
**Dataset:** https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw  
**Resource:** https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw/resource/6857c02f-c77e-4576-b349-3e45aacc1c21  
**Datastore API:** https://nwdp.nwic.gov.in/api/3/action/datastore_search

The dataset contains station, agency, State/District LGD codes, tehsil, latitude, longitude, RL MSL, acquisition time and reported groundwater telemetry value in metres. The portal metadata checked on 6 November 2026 showed a CSV resource with an “Other (Open)” licence. An exact District=Coimbatore API filter returned 14,643 records.

### Integration boundary
SAMANVAY imports the Coimbatore district subset as official station observations. It is not a live sensor connection and does not represent every private borewell. The source's signed numeric values are preserved as published; do not silently convert sign conventions or infer groundwater safety, extraction legality or sustainability. Source timestamps are stored as local timestamps without inventing a timezone. Every imported row retains its NWDP resource ID, source record ID and source URL.

The current integration is intentionally a Coimbatore pilot. The statewide resource contains approximately 921,523 rows and should not be copied wholesale into a free-plan project without a storage/retention plan. Other Tamil Nadu districts can be added in controlled batches after reviewing coverage, freshness and project capacity. The Supabase Edge Function import-nwdp-coimbatore-groundwater is deployed with JWT verification, a single-active-run guard and a six-hour freshness window. The app dashboard and GIS station layer now read the official database view; a signed-in user can start the first import with the Sync Official NWDP Data action. Until that action completes, the database remains empty.

## 2. Underground utilities — authoritative data access required

### Coimbatore City Municipal Corporation (CCMC)
The official Water Supply page states that CCMC maintains the city's drinking-water distribution system. The official UGD page describes its underground drainage responsibility and publishes project reports for specific areas. The Engineering Department is responsible for maintenance of roads, water supply and underground drainage; the Town Planning section lists GIS and asset-management functions.

Official references:
- Water Supply: https://ccmc.gov.in/index.php/department/water-supply
- UGD: https://ccmc.gov.in/index.php/department/ugd
- Engineering / Executive Engineer (Planning): https://ccmc.gov.in/index.php/mainadministration/executive-engineer-planning
- Town Planning: https://ccmc.gov.in/index.php/cat-department/town-planning-tpo

**Finding:** these public pages establish agency responsibility but do not provide a downloadable, georeferenced citywide pipe/drain asset register. SAMANVAY must request approved GIS/CAD records directly from CCMC and relevant asset owners.

### Additional official Coimbatore engineering records

CCMC publishes three volumes under its 24/7 Water Supply project page. These are useful engineering-document leads, but the public page does not describe them as a current machine-readable GIS asset export or certified as-built register. They must be treated as project documents until the Engineering Department confirms which drawings are final, constructed and current.

- 24/7 Water Supply — Volumes 1–3: https://ccmc.gov.in/index.php/createpage/24-7-water-supply
- Water Supply Department: https://ccmc.gov.in/index.php/department/water-supply

CCMC's public Asset Management System page currently says that the page is still under development. This does not prove the Corporation has no internal asset-management system; it means no public asset register was available from that page during this review.

- Asset Management System page: https://ccmc.gov.in/search/2910

CCMC's UGD page publishes project reports for TNUFIP Tranche 1 (Kurichi and Kuniyamuthur) and Tranche 3 (Vadavalli, Veerakeralam, Kavundampalayam and Thudiyalur). The updated Tranche 3 Initial Environmental Examination is also listed by the Asian Development Bank in April 2026. These are project/environmental documents, not proof of completed as-built utility geometry. The report contains project-area and site-set-out plans; the responsible project implementation unit should provide the final as-built CAD/GIS, manhole register, invert levels and completion/commissioning status before any line is admitted as a verified asset.

- CCMC UGD project documents: https://ccmc.gov.in/index.php/department/ugd
- ADB TNUFIP Tranche 3 project documents: https://www.adb.org/projects/49107-010/main
- ADB TNUFIP Tranche 1 project documents: https://www.adb.org/projects/49107-004/main

The Coimbatore City Development Plan (2006) includes a schematic “Existing water supply system” map and recommends GIS mapping/asset management for water-supply and sewerage networks. This is historical planning evidence only; it must not be treated as current pipe geometry or used for excavation clearance.

- City Development Plan (2006): https://ccmc.gov.in/images/stories/CDP/City_Development_Plan.pdf

### Legacy Coimbatore GIS and utility asset-management leads

CCMC's published GIS page records a city GIS study initiated in 2008, initially described as a property-focused GIS for property tax and related municipal services. It also describes intended integration with AutoDCR, Asset Management and engineering estimation systems. CCMC's achievements page separately lists GIS and Asset Management software. These are important leads for a formal data request, but they do not establish that current, accurate underground pipe/drain geometries are available or maintained in a present-day export.

The Coimbatore City Development Plan (2006) recommended mapping/GIS for water-supply network location, characteristics, age and condition, and separately recommended mapping/GIS and an asset-management plan for underground sewerage. This establishes that the need was recognised in historical planning documents; it is not proof that the proposed datasets were completed or remain current.

References:
- CCMC GIS study: https://ccmc.gov.in/index.php/createpage/geographical-information-system-and40gisand41
- CCMC achievements: https://ccmc.gov.in/index.php/createpage/achievements
- Coimbatore City Development Plan: https://ccmc.gov.in/images/stories/CDP/City_Development_Plan.pdf

The TNGIS CUMTA map editor exposes a public-utilities/drainage theme, but the application is labelled CUMTA and its coverage is not established as Coimbatore. It is therefore not admitted to the Coimbatore utility registry. The WRD GIS tank portal is a login-based tank information system, not a public buried-utility asset feed.

### Tamil Nadu Geographical Information System (TNGIS / TNeGA)
TNGIS states that its data is collated from departments and remains owned by the respective departments. Its disclaimer requires TNeGA approval for commercial use/applications. Request the relevant Coimbatore utility layers, data dictionary, licence and written permission before copying them into SAMANVAY.

Portal: https://tngis.tn.gov.in/apps.html  
Support: tngis.support@tn.gov.in | +91-44-40164907

### Survey of India
The Survey of India publishes a Chennai Utility Map entry with vector coverage of 55.75 sq km, supplied offline to government agencies/organisations. This is Chennai coverage, not Coimbatore; it must not be used as a substitute for Coimbatore assets.

Reference: https://surveyofindia.gov.in/pages/availability-of-ori-and-dem

## 3. Building approvals — official transaction portal, no bulk export verified

The Tamil Nadu Commissionerate of Municipal Administration portal exposes building-plan approval search by ULB, applicant, service request, approval number, surveyor and date/status. Property assessment views expose approval number/date, location, plot/approved plot area and floor details. The portal also shows building height and proposed/present floor information in the application workflow.

Official pages:
- Building plan approval search: https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx
- Approval-number search: https://tnurbanepay.tn.gov.in/BPM_SearchBPApprovalNumber.aspx
- Property assessment view: https://tnurbanepay.tn.gov.in/PT_AssessmentViewsLink.aspx
- Building plan workflow: https://tnurbanepay.tn.gov.in/BPM_LayoutBuildingApproval.aspx

The public Building Plan Approval Search page lists fields for ULB, request type, applicant, mobile number, service request number, approval number, surveyor and date/status. During a live interactive check, a usable Coimbatore ULB selector was not exposed, so no unscoped records were queried and no applicant contact details were collected. This discrepancy between indexed page content and the live form must be resolved with the portal operator before any automated extraction.

**Finding:** individual approval searches and authenticated property/application workflows are visible, but a public bulk Coimbatore export of approved plans, floor counts, heights and geospatial footprints was not verified. SAMANVAY should use authority-issued records uploaded or API-shared by the relevant planning authority, not scrape personal applicant details or infer approval from property-tax fields.

## 4. Data admission rules for the live registry

| Data class | Minimum admission evidence | SAMANVAY status |
| --- | --- | --- |
| Underground utility geometry | Asset-owner GIS/CAD record plus written source/usage permission, coordinate reference system, survey date and accuracy | Awaiting CCMC / utility-owner data |
| Building approval | Authority-issued approval/permit and sanctioned plan or authenticated authority response; parcel/building identifier and approval date | Awaiting authority records |
| Groundwater station observation | NWDP record ID, station, coordinates, source timestamp and published value | Importable official dataset; Coimbatore pilot integration |
| Field survey asset | Survey evidence, method, date, organisation and horizontal/vertical accuracy; owner verification before operational use | Not automatically verified |

Never mark a utility as verified solely because it appears in a public map or a field observation. Never label a building as illegal solely from an observed floor count. Never equate a regional groundwater station with a nearby individual borewell.
