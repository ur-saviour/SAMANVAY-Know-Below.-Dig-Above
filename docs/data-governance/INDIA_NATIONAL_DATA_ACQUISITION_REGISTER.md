# SAMANVAY — India National Data Acquisition Register

**Status:** Research baseline / acquisition plan  
**Checked:** 6 November 2026  
**Scope:** National agencies and platforms; to be federated with the Tamil Nadu register.

> **Core rule:** National basemaps, satellite imagery, hydrology and planning layers are not proof of exact underground utility locations. Operational water, sewer, electricity, gas and telecom geometry must come from the current asset owner or competent local authority, with explicit permission and source accuracy.

## 1. Architecture decision

SAMANVAY should use a federated data model, not attempt to create a single central “India underground map”.

- National agencies provide policy, foundational geospatial references, metadata discovery, hydrology, groundwater and national-corridor context.
- State governments, ULBs and utility owners provide operational asset registers, as-built drawings, work permits and survey evidence.
- Each imported layer retains its original custodian, licence, version, accuracy, verification state and access restrictions.
- A national portal listing is a discovery route, not automatic permission to download, redistribute or operationally rely on a dataset.

## 2. National authority register

| Priority | Authority / platform | Relevant responsibility | SAMANVAY integration target | Access boundary |
|---|---|---|---|---|
| P0 | Department of Science & Technology (DST) | National geospatial policy and coordination | National Geospatial Policy 2022, acquisition/production guidelines, standards, sensitive-attribute guidance | Policy is public; it does not override dataset-owner restrictions |
| P0 | Survey of India (SoI) | National Mapping Agency; foundational mapping | Topographic/base-map products, administrative mapping, geodetic references, product catalogue and metadata | Product-specific licence, resolution and service conditions |
| P0 | National Spatial Data Infrastructure (NSDI) / National Data Registry (NDR) | National spatial metadata and dataset discovery/interoperability | Discover participating agency datasets, metadata standards, publisher onboarding and service endpoints | Registry presence does not grant unrestricted data access |
| P0 | National Water Informatics Centre (NWIC), Ministry of Jal Shakti | National water-data integration and discovery | River lines, discharge, rainfall, groundwater-quality and other listed water datasets | Validate source agency, units, time coverage, licence and update cycle |
| P0 | Central Ground Water Board (CGWB) | Groundwater assessment and monitoring | Dynamic groundwater resource assessments, monitoring-well time series, groundwater levels/quality and aquifer reports | Not a complete individual borewell register or site-specific permit database |
| P1 | Central Water Commission (CWC) | Hydrology, river-basin and flood monitoring | River discharge, water levels, flood and hydrological records through CWC/NWIC | Not a municipal stormwater asset register |
| P1 | Ministry of Housing & Urban Affairs (MoHUA) / TCPO | Urban planning and infrastructure policy; AMRUT programmes | GIS-based master-planning guidance, urban programme datasets, ULB identifiers and scheme progress | Operational city GIS is generally held by States, ULBs and project agencies |
| P1 | NRSC / ISRO — Bhuvan and NUIS | Remote sensing and urban geospatial applications | Bhuvan thematic layers, NUIS urban geospatial database and approved imagery products | Imagery and thematic layers do not prove buried utility position |
| P1 | MoRTH / NHAI / PM GatiShakti | National highways and multimodal infrastructure planning | Highway ownership/alignment, corridor and project layers, utility-crossing references where authorised | National Master Plan access is role-controlled; public datasets are only an approved subset |
| P1 | National Informatics Centre (NIC) GIS | Government GIS services and integration framework | All-India basemap, government-asset POIs, geocoding/reverse-geocoding and API integration | Confirm onboarding, coverage, rate limits and permitted use |
| P1 | Open Government Data (OGD) Platform India | Government dataset and API discovery | Search water, sanitation, roads, local government, public works and programme datasets | Dataset-specific licence, attribution, API limits and update status |
| P1 | Ministry of Power / Central Electricity Authority (CEA) | Power-sector policy, planning and statistics | National power statistics, planning reports, standards and asset-owner discovery | Sector statistics are not detailed distribution-cable GIS |
| P1 | POWERGRID / State Transmission Utilities / distribution licensees | Transmission and distribution asset ownership | Owner-supplied line, substation, cable, duct and work records where approved | Exact operational geometry requires owner-authorised access |
| P1 | Department of Telecommunications (DoT), telecom licensees and infrastructure providers | Telecom policy, licensing and infrastructure ownership | Owner-specific fibre, duct, chamber and planned-work records | No assumption of a single public national underground telecom inventory |
| P2 | Ministry of Rural Development / PMGSY | Rural roads and programme implementation | Rural road inventory, sanctioned/completed works and available GIS references | Not a source of underground municipal utility networks |
| P2 | Geological Survey of India (GSI) / National Geoscience Data Repository (NGDR), Ministry of Mines | Geological and mineral-exploration data | Relevant geology/geophysics for broad subsurface context | NGDR is not an underground public-utility registry |

## 3. Official portals and verified scope

1. **Survey of India — National Geospatial Policy 2022:** https://surveyofindia.gov.in/pages/national-geospatial-policy-2022  
   National policy framework for geospatial data infrastructure, custodianship, interoperability and access.

2. **DST — Geospatial policy and guidelines:** https://dst.gov.in/geospatial  
   Official policy, geospatial data acquisition/production guidelines, sensitive-attributes guidance, self-certification information and standards references.

3. **NSDI:** https://www.nsdi.gov.in/  
   National spatial-data coordination portal. It links to the National Data Registry, metadata standards and data-sharing framework. Use this as the verified starting point for NDR discovery/onboarding; confirm the current live registry endpoint and access process with NSDI.

4. **National Water Data Portal (NWIC):** https://nwdp.nwic.gov.in/  
   Official portal under the Department of Water Resources, River Development and Ganga Rejuvenation, Ministry of Jal Shakti. Listed datasets include village boundaries, river discharge, rainfall, river lines and groundwater quality. Inspect each dataset's publisher and metadata.

5. **Central Ground Water Board:** https://cgwb.gov.in/  
   Groundwater resource assessments, monitoring and technical reports. Keep monitoring-station observations separate from block-level assessments and individual borewell permits.

6. **MoHUA:** https://mohua.gov.in/  
   Urban policy and programmes. MoHUA's 10 August 2026 release describes GIS-based master planning under AMRUT/AMRUT 2.0; city data access must be established with the relevant State, ULB or implementing agency.

7. **NRSC urban applications / NUIS:** https://www.nrsc.gov.in/nrscnew/Apps_Urban_Apps.php?lang_code=en  
   NRSC describes NUIS, Bhuvan-NUIS and urban geospatial applications. Validate city coverage, scale, vintage, service availability and reuse conditions.

8. **ISRO Bhuvan:** https://bhuvan.nrsc.gov.in/  
   Satellite imagery and thematic geospatial services. Useful for surface context and change detection, not direct underground utility detection.

9. **MoRTH:** https://morth.nic.in/ and **NHAI:** https://nhai.gov.in/  
   National-highway and corridor asset-owner entry points. Request the relevant highway authority's records for road ownership, chainage, projects, utility crossings and permissions.

10. **PM GatiShakti:** https://gatishakti.gov.in/  
    Whole-of-government GIS-based infrastructure planning framework. PIB's 2026 note describes a public platform with approved datasets; do not assume unrestricted access to the National Master Plan or detailed utility routes.

11. **NIC GIS:** https://www.nic.gov.in/service/remote-sensing-gis/  
    NIC describes an all-India basemap, government-asset POIs, geocoding and API-based GIS services. Confirm service onboarding and terms.

12. **OGD Platform India:** https://data.gov.in/  
    National dataset and API discovery. Validate source department, licence, update date, schema, geographic precision and API limits.

13. **NGDR — Ministry of Mines / GSI:** https://geodataindia.gov.in/  
    National Geoscience Data Repository for exploration-related geoscientific data. This is not the general national utility-data registry.

14. **Ministry of Jal Shakti:** https://jalshakti-dowr.gov.in/  
    National water-resource policy and programme context; use NWIC, CWC, CGWB and the relevant state/utility owner for specific datasets.

## 4. National datasets to catalogue

| ID | Dataset | Discovery / custodian | SAMANVAY use | Validation required |
|---|---|---|---|---|
| IN-GEO-001 | National administrative boundaries and foundational maps | SoI / NSDI / NIC GIS | Common spatial reference | Official codes, scale, CRS, vintage and licence |
| IN-GEO-002 | National geospatial metadata and services | NSDI / NDR | Discover data owners and endpoints | Publisher, metadata completeness and access conditions |
| IN-WATR-001 | Rivers, discharge and hydrological observations | NWIC / CWC | Catchment, water-resource and flood context | Station ID, units, datum, timestamp and provenance |
| IN-GW-001 | Groundwater levels, quality and resource assessment | CGWB / NWIC | Groundwater planning and context | Monitoring station vs assessment area; date and method |
| IN-URB-001 | Urban base maps and NUIS layers | NRSC / Bhuvan-NUIS / ULB | Urban planning reference layers | City coverage, scale, update date and licence |
| IN-URB-002 | GIS master plans and AMRUT programme records | MoHUA / TCPO / State / ULB | Planning and programme context | Competent planning authority, approval status and effective date |
| IN-ROAD-001 | National highway network and project works | MoRTH / NHAI / PM GatiShakti | Highway ownership and corridor coordination | Road authority, chainage, project status and access class |
| IN-ROAD-002 | Rural road inventory and works | PMGSY / MoRD | Rural expansion and road-work coordination | Road ID, implementing agency, completion date and geometry source |
| IN-POWR-001 | Power statistics and transmission context | CEA / POWERGRID / STUs | Sector planning and asset-owner discovery | Statistics vs operational asset records |
| IN-TELC-001 | Telecom ducts, fibre and chambers | DoT context; each licensed operator/provider | Multi-utility coordination | Direct owner confirmation, accuracy and disclosure restrictions |
| IN-UTIL-001 | Water, sewer, stormwater, electricity and gas geometry | State, ULB and utility owners | Core clash detection and excavation coordination | Owner, survey evidence, accuracy, permission and update date |
| IN-GEO-003 | Geological/geophysical context | GSI / NGDR | Broad subsurface context where relevant | Scale, purpose and licence; never infer utility routes |

## 5. Data acquisition workflow

For every candidate dataset:

1. Discover it through an official portal or the responsible ministry/agency.
2. Identify both the portal publisher and the authoritative data custodian.
3. Capture the data dictionary, schema, geometry type, CRS, units, geographic coverage and source identifiers.
4. Request update cadence, change history, positional/depth accuracy, survey method and known completeness limitations.
5. Obtain API/service documentation and a test endpoint where available.
6. Obtain written permission for internal use, derived analytics, public display, redistribution and commercial use as applicable.
7. Use the custodian's approved secure transfer and identity/access process for restricted data.
8. Validate in staging; quarantine invalid geometry, CRS, duplicate IDs and incomplete metadata.
9. Preserve original files, checksums, import batch, validation report and audit history.
10. Publish only the approved detail level to authorised roles and reconcile later updates/revocations.

## 6. Shared national-to-state data contract

Every imported feature must retain:

- source_authority_id, source_dataset_id, source_record_id
- custodian_name, publisher_name, jurisdiction, geographic_coverage
- source_url_or_document_ref, source_version, source_updated_at, ingested_at
- geometry_crs, geometry_type, horizontal_accuracy_m, vertical_accuracy_m
- survey_method, depth_reference_datum, asset_owner_department_id
- access_classification, licence_reference, permission_reference
- verification_status, verified_by, verified_at, evidence_refs
- record_status, valid_from, valid_to, supersedes_record_id

Use the same trust states as the Tamil Nadu register: reference layer; department-provided/unverified; owner-confirmed; field-surveyed; disputed/stale/retired. Never silently promote a record.

## 7. Security and product rules

- Public basemaps and datasets are displayed only under their licence, attribution, caching and redistribution terms.
- Exact underground utility geometry is restricted to the asset owner and explicitly authorised cross-agency users.
- Generic platform administrator status does not grant access to every utility's exact routes.
- Public users receive non-sensitive work notices and service status, not exact critical-asset geometry.
- Audit restricted-layer access by user, department, purpose, dataset, spatial extent and timestamp.
- Never infer excavation clearance from satellite imagery, geological layers, modelled coverage or absence of records.
- Clash alerts are advisory; the asset owner and statutory authority retain decision-making authority.

## 8. Rollout

**India-0 — policy and metadata:** confirm SoI/DST policy requirements; establish NSDI/NDR discovery route; catalogue NWIC, CGWB, SoI, NIC GIS and OGD datasets with owners and terms.

**India-1 — reference layers:** integrate approved administrative boundaries, basemaps, public hydrology/groundwater assessments, urban planning and road context.

**India-2 — state/utility federation:** reuse the Tamil Nadu register as the first state adapter; add other States/UTs, ULBs, water boards, power utilities, transmission utilities and telecom owners.

**India-3 — national corridor coordination:** link works on national corridors to the responsible road and utility owners; detect spatial/time overlaps; route for owner review; capture conditions, validity, field verification and as-built updates.

## 9. Acceptance criteria

- [ ] Each dataset has an authoritative custodian, publisher and jurisdiction.
- [ ] Coverage, scale, CRS, date, accuracy and licence are recorded.
- [ ] National context layers are not misrepresented as underground utility records.
- [ ] Restricted data has written permission and owner-scoped access.
- [ ] State/local utility records retain their actual owner and source lineage.
- [ ] Registry presence is not treated as unrestricted download entitlement.
- [ ] Empty results mean “no authorised records returned”, never “no underground assets”.
- [ ] National and state records link without losing original identifiers or provenance.
- [ ] Every clash alert is routed to the responsible authority; the software does not issue statutory clearance.

## 10. Official source links

- SoI National Geospatial Policy 2022: https://surveyofindia.gov.in/pages/national-geospatial-policy-2022
- DST geospatial policy/guidelines: https://dst.gov.in/geospatial
- NSDI: https://www.nsdi.gov.in/
- NWIC National Water Data Portal: https://nwdp.nwic.gov.in/
- CGWB: https://cgwb.gov.in/
- MoHUA: https://mohua.gov.in/
- NRSC urban applications / NUIS: https://www.nrsc.gov.in/nrscnew/Apps_Urban_Apps.php?lang_code=en
- ISRO Bhuvan: https://bhuvan.nrsc.gov.in/
- MoRTH: https://morth.nic.in/
- NHAI: https://nhai.gov.in/
- PM GatiShakti: https://gatishakti.gov.in/
- NIC GIS: https://www.nic.gov.in/service/remote-sensing-gis/
- OGD Platform India: https://data.gov.in/
- NGDR: https://geodataindia.gov.in/
- Ministry of Jal Shakti: https://jalshakti-dowr.gov.in/

**Research caution:** Portal endpoints, agency mandates, data licences and access rules can change. Confirm them directly before production integration. This register is a sourced acquisition plan, not evidence that SAMANVAY has received datasets, credentials or government endorsement.
