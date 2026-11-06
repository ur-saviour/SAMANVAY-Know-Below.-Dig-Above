# SAMANVAY — Coimbatore Pilot Authority Mapping

**Status:** Working authority map for pilot configuration  
**Checked:** 6 November 2026  
**Scope:** Coimbatore City Municipal Corporation area, Tamil Nadu  
**Purpose:** Translate SAMANVAY's existing functional department routes into the real asset-owning / statutory authorities that must be consulted.

> This is a planning map, not an official government directory or proof of agency participation. Confirm the competent office, asset ownership boundary and current designation directly before assigning cases or importing data. No agency is represented as having endorsed SAMANVAY.

## 1. Important distinction in the current database

The Supabase `public.departments` table currently contains 11 functional service groups:

- Electricity
- Gas
- Groundwater & Borewell Regulation
- Municipal Corporation
- Public Health Engineering
- Roads & Highways
- Sewage and Drainage
- Stormwater Management
- Telecommunications
- Town Planning & Building Regulation
- Water Supply

These are useful workflow categories. They are **not yet verified real-world authority accounts**. The database also contains service-domain routing rules, but a generic category is not enough to establish who owns a particular road segment, water scheme, pipe, cable or permit.

For production, retain functional service categories and create/maintain jurisdiction-specific authority units beneath them. Example: the functional group “Water Supply” may route to CCMC for a municipal-owned network and to TWAD for a TWAD-owned scheme. The asset owner—not the category label—determines who receives exact-asset access and clearance requests.

## 2. Coimbatore authority mapping

| Existing functional group | Primary Coimbatore / Tamil Nadu authority to verify | Supporting authorities / owners | Records and responsibilities to request |
|---|---|---|---|
| Municipal Corporation | Coimbatore City Municipal Corporation (CCMC) | Commissionerate of Municipal Administration (CMA); relevant district administration | Ward/road ownership, municipal asset register, local public works, road-cut permits, restoration, municipal service records |
| Water Supply | CCMC or Tamil Nadu Water Supply and Drainage Board (TWAD), depending on scheme ownership | Local scheme operator; relevant water-resource divisions | Water mains, valves, reservoirs, pumping stations, treatment plants, as-built drawings, ownership/maintenance boundary |
| Public Health Engineering | TWAD Board for schemes within its mandate; confirm the exact scheme | CCMC and local public-health engineering offices | Combined water schemes, treatment/pumping assets, sanitation infrastructure, technical drawings and maintenance records |
| Sewage and Drainage | CCMC or TWAD according to scheme/asset ownership | PWD / Water Resources Department where the asset is a water-resource drain or channel | Sewer mains, manholes, pumping stations, treatment plants, sewerage scheme boundaries, as-builts and inspection history |
| Stormwater Management | CCMC for municipal stormwater infrastructure | PWD / WRD for water-resource channels, tanks, canals and flood-control assets | Stormwater drains, outfalls, culverts, catchments, maintenance schedules, flood works and inspection records |
| Roads & Highways | CCMC for corporation roads; Tamil Nadu Highways Department for state roads | NHAI / MoRTH for national highways; CMA for municipal coordination | Segment-level road owner, road centreline, right-of-way/chainage, road-cut approvals, utility shifting, resurfacing and restoration |
| Electricity | Tamil Nadu Power Distribution Corporation Limited (TNPDCL), subject to current local distribution-circle structure | Transmission utility where relevant; authorised electrical contractors | Underground cables/ducts where recorded, feeders, substations, transformer assets, planned works, permits and emergency escalation |
| Telecommunications | Each actual telecom infrastructure / service provider that owns the duct or fibre | Department of Telecommunications (DoT) for licensing/policy context; local road owner for permissions | Fibre/duct/chamber routes, planned work, owner identity, survey date/accuracy and emergency contact; no assumed single state-owned inventory |
| Gas | The authorised city-gas / pipeline asset owner for the specific area | Petroleum and Natural Gas Regulatory Board (PNGRB) for regulatory context; road owner for permissions | Pipeline owner, approved route/ROW, work permits, isolation/emergency contact, survey evidence and asset status |
| Groundwater & Borewell Regulation | Competent Tamil Nadu groundwater / Water Resources Department authority and the local permitting authority; confirm by applicable rules and location | Central Ground Water Board (CGWB); district administration; CCMC | Borewell permissions/registers where maintained, monitoring-well observations, groundwater assessment, NOC/permit references and inspection records |
| Town Planning & Building Regulation | CCMC planning/building-permission authority for its jurisdiction | Directorate of Town and Country Planning (DTCP) / competent local planning authority | Approved plan/layout identifiers, land-use/master-plan layers, permitted floors, approval status and enforcement/inspection references |

### Jurisdiction rules

1. **Road ownership is segment-specific.** Do not route every road case to CCMC. Determine whether the segment belongs to CCMC, State Highways, NHAI or another competent authority.
2. **Water and sewer ownership is scheme-specific.** TWAD's statewide mandate excludes the Chennai Metropolitan Area, but it does not mean every Coimbatore pipe is TWAD-owned. Confirm each scheme and transfer/maintenance arrangement.
3. **Stormwater drains are not all the same asset class.** A municipal storm drain, a natural channel, a WRD canal and a surface drainage layer require different owners and workflows.
4. **Telecom and gas are not necessarily government departments.** The actual infrastructure owner/operator must be recorded; regulators and permission authorities are not substitutes for asset owners.
5. **Groundwater monitoring is not a borewell register.** CGWB or telemetry data may describe aquifer conditions or monitoring stations, not every private borewell or permit.
6. **Building approval jurisdiction varies.** Confirm whether CCMC, DTCP or another planning authority issued the approval for the particular parcel.

## 3. Suggested pilot routing matrix

Use this as the initial review-routing template only. The real authority unit must be selected after the road, parcel, scheme and asset-owner checks.

| Case category | Primary review route | Supporting review route |
|---|---|---|
| road_reconstruction | Owner of the affected road segment | Every utility owner intersecting the work footprint |
| water_supply | Verified water-scheme asset owner | CCMC / TWAD / public-health engineering as applicable |
| sewerage | Verified sewerage asset owner | CCMC / TWAD / public-health engineering as applicable |
| stormwater_drainage | Owner of the affected stormwater asset | CCMC / PWD-WRD / relevant local body |
| electricity | TNPDCL or other verified distribution owner | Road owner; transmission utility if affected |
| telecom | Verified duct/fibre owner | Road owner; other utilities in the work corridor |
| gas | Verified pipeline operator | Road owner; other affected utilities |
| borewell_groundwater | Competent state/local groundwater authority | District administration; CGWB for monitoring/resource context |
| building_planning | Competent planning/building authority | CCMC engineering/public-health services where legally relevant |
| public_health_engineering | Competent TWAD / local public-health engineering authority | CCMC and water/sewer asset owners |
| other | Jurisdiction-matched local-body coordinator | Determined by the case description and affected assets |

## 4. Minimum authority registry fields

Before activating real departmental accounts, add a governed authority registry. Recommended fields:

- `authority_id` — stable internal UUID
- `functional_department_id` — link to the existing service group
- `official_name`, `abbreviation`, `legacy_names`
- `authority_level` — central / state / district / ULB / utility-owner
- `state_code`, `district_code`, `local_body_code`, `ward_scope`
- `parent_authority_id`
- `mandate_summary`, `asset_types_owned`, `case_categories`
- `official_website`, `official_contact_route`
- `data_steward_role`, `escalation_route`
- `source_reference`, `verified_at`, `verification_status`
- `data_sharing_agreement_ref`, `access_classification`

Do not place personal phone numbers, private email addresses or staff names into the public repository. Store approved official contact routes and role-based contact details in the governed database only after verification.

## 5. Coimbatore pilot data-request order

1. **CCMC:** ward boundaries, road inventory and ownership, road-cut permits, planned/completed works, stormwater asset register, building/layout approval references.
2. **TNeGA / TNGIS:** common administrative GIS layers, catalogue metadata, API/download instructions, data-owner mapping and written approval route.
3. **TWAD:** Coimbatore-area water and sewer scheme ownership, asset registers, as-built records and maintenance boundaries.
4. **TNPDCL:** authorised GIS nodal office, underground distribution asset availability, approved export/API and access classification.
5. **Tamil Nadu Highways / NHAI:** road ownership and corridor work records for roads not controlled by CCMC.
6. **PWD / WRD:** tank, channel, canal, flood-control and water-resource asset records within the pilot boundary.
7. **Telecom / gas asset owners:** identify the actual licensed operator and request only the approved owner-supplied route/permit data.
8. **Groundwater authorities:** groundwater monitoring and borewell permit/register records as separate datasets, with distinct provenance.

Every request should ask for schema, CRS, geometry type, positional/depth accuracy, source date, update cadence, owner, permission/licence, secure transfer method and named role-based data steward.

## 6. Go-live gates

- [ ] Functional department groups are mapped to actual authority units for the pilot boundary.
- [ ] Every road segment has a verified road-owning authority or an explicit unknown-owner state.
- [ ] Every underground asset has an authoritative owner, source reference, CRS, accuracy and verification state.
- [ ] The relevant authority has approved the data-sharing purpose and access method.
- [ ] Exact geometry is visible only to the owner and specifically authorised cross-agency roles.
- [ ] Public/requester views do not expose sensitive exact utility geometry.
- [ ] A missing record is shown as “no authorised record available”, never “no utility present”.
- [ ] Clash/proximity results remain advisory and do not represent statutory excavation clearance.
- [ ] Every approval, refusal, inspection, field survey and as-built update is auditable.

## 7. Official source entry points

- CCMC: https://www.ccmc.gov.in/
- CMA: https://www.tnurbantree.tn.gov.in/
- TNGIS: https://tngis.tn.gov.in/
- Directorate of e-Governance, Tamil Nadu: https://deg.tn.gov.in/
- TWAD Board: https://www.twadboard.tn.gov.in/ and https://twadeodb.tn.gov.in/
- Tamil Nadu Highways Department: https://www.tnhighways.tn.gov.in/
- Tamil Nadu WRD / PWD entry point: https://www.tn.gov.in/department/
- TNPDCL / legacy TANGEDCO portal: https://www.tangedco.com/en/
- DTCP: https://tcp.tn.gov.in/
- Tamil Nadu online planning permission: https://onlineppa.tn.gov.in/
- CGWB: https://cgwb.gov.in/
- MoHUA: https://mohua.gov.in/
- NHAI: https://nhai.gov.in/

**Final limitation:** This mapping identifies who should be approached and what must be verified. It does not prove that these agencies have supplied data, accepted SAMANVAY, or authorised excavation. Production routing must be confirmed by the competent authority and asset owner.
