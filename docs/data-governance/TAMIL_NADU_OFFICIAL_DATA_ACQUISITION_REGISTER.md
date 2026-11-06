# SAMANVAY — Tamil Nadu Official Data Acquisition Register

**Document status:** Research baseline / acquisition plan  
**Research checked:** 6 November 2026  
**Geographic scope:** Tamil Nadu statewide; Coimbatore is the proposed first local-body pilot  
**Purpose:** Identify authoritative custodians, official data entry points, datasets to request, access constraints and the ingestion sequence for SAMANVAY.

> **Critical data rule:** A public map layer, planning drawing, complaint location or modelled coverage cell is not proof of an underground utility's exact location. Exact geometry must retain source lineage and be labelled by verification state. An empty database or an empty map response must never be represented as “no utility” or “safe to excavate”.

## 1. Executive decision

Build the Tamil Nadu integration around **TNeGA / Directorate of e-Governance (TNGIS)** as the geospatial coordination entry point, while obtaining operational asset records from the **department or utility that owns and maintains each asset**. For the Coimbatore pilot, the municipal corporation is the local-body anchor; CMA is the state-level coordination route for municipalities and corporations other than Chennai.

Do not scrape or redistribute restricted portal layers. TNGIS terms state that its GIS data is informational, not for legal use, may not be republished without prior permission, is not for commercial use without TNeGA approval, and remains owned by the contributing departments. SAMANVAY must obtain written permission and dataset-specific licence conditions before production ingestion.

## 2. Tamil Nadu authority register

Priority is based on SAMANVAY's underground-infrastructure and multi-agency coordination use case, not on a claim that the authority has already agreed to share data.

| Priority | Authority / custodian | Jurisdiction / role | SAMANVAY records to request | Official entry point |
|---|---|---|---|---|
| P0 | Directorate of e-Governance / TNeGA — TNGIS | State GIS platform and inter-department geospatial coordination | Layer catalogue; metadata; service/API catalogue; download formats; coordinate reference systems; update dates; data-owner contacts; access and commercial-use approval process | https://tngis.tn.gov.in/apps.html · https://deg.tn.gov.in/ |
| P0 | Coimbatore City Municipal Corporation (CCMC) | Local-body anchor for the proposed Coimbatore pilot; municipal roads and local services within its jurisdiction, subject to asset ownership | Ward boundaries; road centre-lines and road ownership/class; road-cut permissions; road-restoration works; stormwater drains; municipal water/sewer assets where owned/maintained; work orders; asset registers; as-built drawings; building-plan approvals and public works history | https://www.ccmc.gov.in/ |
| P0 | Commissionerate of Municipal Administration (CMA) | Coordinates and supervises municipalities and municipal corporations other than Chennai Corporation | State ULB directory and codes; standard datasets; municipal e-governance integration route; road-cutting / restoration process; local-body GIS and asset data custodians | https://www.tnurbantree.tn.gov.in/ |
| P0 | Tamil Nadu Water Supply and Drainage Board (TWAD) | Water-supply and sewerage facilities across Tamil Nadu except Chennai Metropolitan Area; confirm scheme and asset ownership for each locality | Combined water-supply scheme alignments; transmission/distribution mains; pumping stations; reservoirs; treatment plants; sewerage schemes; as-built drawings; asset owner and maintenance boundary; survey metadata | https://www.twadboard.tn.gov.in/ · https://twadeodb.tn.gov.in/ |
| P0 | Tamil Nadu Power Distribution Corporation Limited (TNPDCL; formerly TANGEDCO) | Electricity distribution network and related assets | Underground cable and duct records where held; feeder/substation/transformer asset metadata; work permits; planned maintenance and cable-laying records; asset custodian and disclosure classification | https://www.tangedco.com/en/ |
| P1 | Tamil Nadu Highways Department | State highways and roads under its control; road ownership must be checked for each segment | Road inventory; road classification; chainage/ROW; bridges/culverts; resurfacing and widening plans; road-cut permissions and restoration conditions; utility-shifting records | https://www.tnhighways.tn.gov.in/ |
| P1 | Public Works Department (PWD) / Water Resources Department (WRD) | Public works and water-resource assets within their respective mandates | Relevant departmental asset registers; canals, drains, water bodies, flood-control assets, culverts and project drawings; identify exact owning division before request | https://www.tn.gov.in/department/ |
| P1 | Directorate of Town Panchayats | Town Panchayat local-body administration | Town Panchayat boundaries/codes; water and sanitation assets; local roads and drains; work and permission registers; local GIS and service data | https://www.dtp.tn.gov.in/ |
| P1 | Directorate of Town and Country Planning (DTCP) / local planning authority | Statutory planning, layouts and building development permissions within its jurisdiction | Approved layouts; master/development plans; planning-area boundaries; building/layout approval identifiers and status; applicable development-control rules | https://tcp.tn.gov.in/ · https://onlineppa.tn.gov.in/ |
| P1 | Central Ground Water Board (CGWB), Ministry of Jal Shakti, and Tamil Nadu groundwater authorities | Groundwater monitoring and resource assessment; not a complete individual borewell inventory | Block/district resource assessments; monitoring-well locations and time series; water-level and quality datasets; assessment methodology; available borewell registration/permit datasets from the competent state authority | https://cgwb.gov.in/cgwbpnm/ |
| P2 | Chennai Metropolitan Water Supply and Sewerage Board (CMWSSB) | Water supply and sewerage in Chennai Metropolitan Area; not the Coimbatore pilot custodian | Chennai-specific water/sewer network and work data for later Chennai rollout | https://cmwssb.tn.gov.in/ |
| P2 | Telecom infrastructure owners / licensed telecom service providers | Owner-specific fibre, duct and telecom assets | Duct/fibre route records; manhole/chamber inventory; planned works; survey date/accuracy; emergency contact and disclosure restrictions | Request through each verified asset owner; do not assume a single public state inventory exists |
| P2 | National Highways Authority of India (NHAI) / MoRTH | National highways and associated works, where applicable | Highway ownership and chainage; utility crossings; permissions; work programmes and restoration conditions | https://nhai.gov.in/ |

**Naming correction:** The state power distribution company is referred to as TNPDCL following the 2024 restructuring/renaming notice on the official electricity portal. Keep the historical alias “TANGEDCO” in search terms and legacy records, but store the current verified legal entity name from the latest official corporate notice before executing agreements.

## 3. Verified official sources and what they establish

1. **TNGIS portal and terms:** https://tngis.tn.gov.in/apps.html and https://tngis.tn.gov.in/user.html  
   TNGIS describes a state spatial-data infrastructure. Its terms say portal GIS is for informational purposes, not legal use; prior approval is required for republishing; commercial use requires TNeGA approval; underlying data ownership remains with the respective departments. This is a permission gate, not a blanket licence to import data.

2. **Directorate of e-Governance:** https://deg.tn.gov.in/  
   The Directorate describes TNGIS as hosting 400+ spatial layers, with 200+ regularly shared with departments, and provides a government onboarding/contact route. This supports using TNeGA/DeG as the first coordination contact; it does not establish that every layer is public or contains underground networks.

3. **TNGIS layer catalogue:** https://tngis.tn.gov.in/apps.html  
   Review the actual layer metadata and service terms individually. Do not infer exact water, sewer, electrical or telecom alignments merely from the presence of a “drainage”, “road” or “utility” themed layer.

4. **CMA jurisdiction:** https://www.tnurbantree.tn.gov.in/about-us/  
   CMA states that it coordinates and supervises municipalities and municipal corporations other than Chennai Corporation. Therefore, Coimbatore's local-body route should include CCMC and CMA; Chennai-specific systems should not be used as a proxy for Coimbatore.

5. **TWAD mandate:** https://twadeodb.tn.gov.in/  
   TWAD states that it is responsible for water-supply and sewerage facilities across Tamil Nadu except Chennai Metropolitan Area. For each scheme, confirm whether TWAD, a local body or another agency owns and maintains the specific asset.

6. **Tamil Nadu Urban Local Bodies Act / Rules:** https://www.tnurbantree.tn.gov.in/acts-and-rules-documents/  
   The Act and 2023 Rules are the statutory starting point for municipal functions. SAMANVAY should store the relevant legal instrument, section/rule, jurisdiction, effective date and source document for each configurable workflow rule.

7. **Official road-cutting application:** https://tnurbanepay.tn.gov.in/Road%20Cutting-Application.pdf  
   The published application explicitly includes optical cable, electrical cable, pipeline and sewer-line work, including trenchless work. It asks for location/site and ward maps, length/extent and restoration-related details. This is a strong basis for SAMANVAY's road-opening permit data model and multi-utility work coordination.

8. **Municipal building/layout approval search:** https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx  
   The portal exposes building-plan and layout approval search fields. Treat it as a workflow/record discovery entry point, not as permission to bulk-harvest personal or restricted application data.

9. **Tamil Nadu Open Data Portal:** https://tn.data.gov.in/ and https://tn.data.gov.in/apis  
   The portal is intended for departments to publish datasets, documents, services and tools. Check each dataset's owner, licence, update date, API limits and spatial detail before ingestion.

10. **CGWB Dynamic Ground Water Resources of Tamil Nadu, 2025:** https://cgwb.gov.in/cgwbpnm/public/publication-detail/2122  
    Official state/block-level groundwater resource assessment. It is useful for planning and context; it is not an individual borewell register or a substitute for site-level borewell permissions and surveys.

11. **Town Panchayats:** https://www.dtp.tn.gov.in/  
    Official portal for Town Panchayat administration and service entry points; include it when the pilot expands beyond municipal corporation limits.

12. **DTCP:** https://tcp.tn.gov.in/ and https://onlineppa.tn.gov.in/  
    Planning and permission systems are relevant to approved layouts, development plans and building controls. Confirm which authority is competent for each planning area before treating a record as authoritative.

13. **Power distribution:** https://www.tangedco.com/en/  
    The official corporate portal reports the distribution organisation and its services. Exact underground cable routes should be requested directly from the current distribution utility's authorised asset custodian.

## 4. Data acquisition backlog — request these first

| ID | Dataset / record | First owner to approach | Required minimum fields | Expected format / handling |
|---|---|---|---|---|
| TN-GIS-001 | State and local administrative boundaries | TNeGA / TNGIS; CCMC for authoritative ward codes | district, taluk, ULB, ward ID/name, geometry, CRS, source, version, effective date | SHP / GeoJSON / GeoPackage / WFS; preserve official codes |
| TN-ROAD-001 | Road inventory and ownership | CCMC; CMA; Highways for state roads | road ID/name, class, owner, limits/chainage, geometry, surface, ROW if available, last work date | GIS + asset register; segment-level owner is mandatory |
| TN-RCUT-001 | Road-cutting permissions and restoration | CCMC / competent road-owning authority | permit ID, applicant agency, purpose, road/ward, geometry, length/width, dates, conditions, restoration deposit/status, completion evidence | API/export or authorised record transfer; link to case/work ID |
| TN-WATR-001 | Water-supply asset register | CCMC and TWAD, based on asset ownership | asset ID, asset type, geometry, material, diameter, depth if surveyed, owner, operator, status, source drawing, survey date/accuracy | CAD/GIS/as-built; exact geometry restricted to authorised roles |
| TN-SEWR-001 | Sewerage and underground drainage | CCMC and TWAD, based on scheme/asset ownership | pipe ID, type, geometry, diameter, invert/cover level, flow direction, manhole IDs, owner, survey and verification evidence | CAD/GIS/as-built; sensitive geometry access-controlled |
| TN-STMW-001 | Stormwater drains and flood assets | CCMC / PWD-WRD / relevant local body | drain ID, type, geometry, dimensions, invert/bed level, outfall, condition, maintenance owner | GIS/CAD + inspection records |
| TN-POWR-001 | Electricity distribution underground assets | TNPDCL / relevant licensee | cable/duct ID, voltage class, geometry, depth/clearance if recorded, asset owner, work status, survey source | Owner-supplied restricted GIS/CAD; no public exact-route display |
| TN-TELC-001 | Telecom ducts/fibre and chambers | Each verified telecom asset owner | owner, asset ID, duct/chamber type, geometry, depth if known, survey date, contact/escalation | Owner-supplied GIS/CAD; tenant separation and access control |
| TN-BLDG-001 | Building/layout approval references | CCMC / DTCP / competent planning authority | approval ID, plot/parcel reference, permitted use/floors where lawfully shareable, approval status/date, authority, plan version | Official API/export or officer-verified lookup; minimise personal data |
| TN-GW-001 | Groundwater assessment and borewell regulatory records | CGWB + competent Tamil Nadu groundwater authority + local body | block, assessment year, monitoring station, water level/quality, borewell permit/register fields if maintained | CSV/GIS/report; distinguish regional assessment from individual wells |
| TN-WORK-001 | Planned and completed public works | Every asset/road-owning authority | work ID, department, contractor where disclosable, geometry, scope, schedule, status, affected roads/utilities, completion evidence | Structured work register + GIS geometry |
| TN-BASE-001 | Basemap, terrain and imagery usage rights | TNeGA / relevant licensed provider | provider, coverage, CRS, resolution, attribution, licence, caching/redistribution terms | Approved service URL or licensed tiles; no undocumented scraping |

## 5. Standard data-sharing request package

Send one coordinated request to TNeGA/DeG and separate asset-specific requests to each custodian. Request the following for every dataset:

- Dataset title, purpose, geographic coverage and authoritative owner/custodian.
- Data dictionary, unique identifiers, geometry type, coordinate reference system and units.
- Current export/API/service endpoint and supported formats (GeoPackage, SHP, GeoJSON, WFS/WMS, CAD or documented API).
- Last updated date, update cadence, change-log/versioning method and known completeness limitations.
- Positional accuracy, survey method, depth/level datum and evidence for underground geometry.
- Access classification, licence, permitted internal/public/commercial use, attribution and redistribution restrictions.
- Whether derivative analysis (e.g. proximity/conflict alerts) is permitted.
- Secure transfer method, named departmental data steward, escalation contact and data-retention conditions.
- Written approval for SAMANVAY's intended use and any pilot / sandbox conditions.

**Do not ask departments to email sensitive exact utility routes to an ordinary personal inbox.** Request their approved secure transfer method and access-control requirements. Never store credentials or API secrets in the repository.

## 6. SAMANVAY ingestion and trust model

Every imported feature must carry lineage. Recommended minimum metadata:

- `source_authority_id`, `source_dataset_id`, `source_record_id`
- `source_url_or_document_ref`, `source_version`, `source_updated_at`, `ingested_at`
- `geometry_crs`, `geometry_accuracy_m`, `depth_accuracy_m`, `survey_method`
- `asset_owner_department_id`, `operating_department_id`
- `access_classification`, `licence_reference`, `permission_reference`
- `verification_status`, `verified_by`, `verified_at`, `evidence_refs`
- `record_status` (active / proposed / retired / disputed / unknown)

Use distinct trust states:

1. **Reference layer** — official context/basemap, not an underground asset.
2. **Department-provided, unverified** — received from a custodian but not yet quality-checked.
3. **Owner-confirmed** — custodian confirms identity/ownership and record currency.
4. **Field-surveyed** — survey evidence, method, date and accuracy recorded.
5. **Disputed / stale / retired** — visible to authorised reviewers with warnings; excluded from positive clearance claims.

Never silently upgrade a record's trust state. Preserve the original source file and a checksum, import batch ID, validation report and audit trail. Quarantine invalid CRS, geometry, duplicate IDs and unsupported schemas.

## 7. Security and disclosure controls

- Exact utility geometry: only authorised personnel of the owning utility/department and explicitly approved cross-agency users.
- General public/requesters: show work notices, responsible agency and safe, non-sensitive status information; do not expose exact utility routes.
- Coordinators: show only the minimum data needed for lawful coordination; detailed geometry requires explicit owner-granted scope.
- Administrators: platform administration does not automatically grant entitlement to every utility's exact geometry.
- All access to restricted layers must be logged with user, role, department, purpose, dataset, extent and timestamp.
- Encrypt data in transit and at rest; use least-privilege credentials, signed URLs or approved service accounts, and secret storage outside Git.
- Apply retention, deletion, breach reporting and data-sharing agreement requirements set by each custodian.
- Do not use public TNGIS layers for legal excavation clearance. Clearance must be based on the authorised asset owner's current records and prescribed field-verification process.

## 8. Implementation sequence

**Phase TN-0 — permission and metadata (now)**
1. Contact TNeGA/DeG for the current TNGIS layer catalogue, APIs, metadata and formal approval route.
2. Establish CCMC as Coimbatore pilot local-body counterpart; identify GIS, roads, water, sewerage, stormwater and town-planning nodal officers.
3. Identify asset ownership boundaries for every water/sewer scheme; do not assume CCMC and TWAD ownership is identical.
4. Obtain written data-sharing and permitted-use conditions before production imports.

**Phase TN-1 — low-risk foundation layers**
1. Approved administrative and ward boundaries.
2. Road centre-lines and road ownership.
3. Official water bodies / drainage context layers where licensed.
4. Road-cutting permit schema and public works register.

**Phase TN-2 — authoritative underground asset records**
1. Water and sewer assets from CCMC/TWAD according to ownership.
2. Stormwater assets from the responsible local body / PWD-WRD.
3. Electricity underground assets from TNPDCL.
4. Telecom duct/fibre records from each owner.
5. Import only with source CRS, survey accuracy, permission reference and custodian identity.

**Phase TN-3 — operational coordination**
1. Link excavation requests to affected road and utility owners.
2. Detect spatial + time-window overlap between planned works.
3. Request owner review; record response, conditions and validity window.
4. Require statutory approvals and field verification as applicable; software advisory is not legal clearance.
5. Track restoration, inspection, as-built update and closure.

**Phase TN-4 — statewide expansion**
Reuse the same register and ingestion contracts for other corporations, municipalities and Town Panchayats. Chennai requires its own CMWSSB and Greater Chennai Corporation data-owner mapping.

## 9. Acceptance criteria for the Tamil Nadu data work

- [ ] Every dataset has a named authoritative custodian and geographic scope.
- [ ] Every dataset has a documented licence / written permission status.
- [ ] Every spatial dataset declares CRS, geometry type, version and update date.
- [ ] Every underground asset has owner, source, survey evidence and explicit trust state.
- [ ] Public and staff map views enforce different access scopes.
- [ ] No exact utility route is exposed solely because a user has the generic administrator role.
- [ ] Empty query results are labelled “no authorised records returned”, never “no underground assets”.
- [ ] Road-cutting workflows capture purpose, road owner, location, work extent, schedule, restoration obligations and completion evidence.
- [ ] Clash alerts are advisory until the responsible authority records its decision.
- [ ] Coimbatore pilot can be expanded to another ULB without changing the core data model.

## 10. India expansion — reserved next stage

After Tamil Nadu's authority, permission and ingestion model is operational, extend the same registry to national custodians: Survey of India; DST / National Geospatial Data Registry and NSDI; Ministry of Jal Shakti / CGWB; MoHUA; MoRTH / NHAI; Ministry of Power and relevant central regulators; and OGD Platform India. Do not mix national context layers with state/local asset-owner records without retaining the original custodian and licence.

---

## Source links (official)

- TNGIS apps and terms: https://tngis.tn.gov.in/apps.html · https://tngis.tn.gov.in/user.html
- Directorate of e-Governance: https://deg.tn.gov.in/
- TNGIS programme overview: https://it.tn.gov.in/en/TNEGA/TNGIS
- CMA: https://www.tnurbantree.tn.gov.in/about-us/
- Tamil Nadu Urban Local Bodies Acts and Rules: https://www.tnurbantree.tn.gov.in/acts-and-rules-documents/
- Road-cutting application: https://tnurbanepay.tn.gov.in/Road%20Cutting-Application.pdf
- Building/layout approval search: https://tnurbanepay.tn.gov.in/BPM_SearchLayoutApprovals.aspx
- TWAD: https://www.twadboard.tn.gov.in/ · https://twadeodb.tn.gov.in/
- TN Open Data: https://tn.data.gov.in/ · https://tn.data.gov.in/apis
- Town Panchayats: https://www.dtp.tn.gov.in/
- DTCP: https://tcp.tn.gov.in/ · https://onlineppa.tn.gov.in/
- TNPDCL/TANGEDCO portal: https://www.tangedco.com/en/
- CGWB Tamil Nadu 2025 assessment: https://cgwb.gov.in/cgwbpnm/public/publication-detail/2122
- CMWSSB: https://cmwssb.tn.gov.in/
- NHAI: https://nhai.gov.in/

**Research caution:** Portal content, organisation names, legal instruments, URLs, data formats and access terms can change. Revalidate with the custodian and obtain written approval before any production integration. This register is a sourced acquisition plan, not evidence that SAMANVAY has received the datasets or that any authority has endorsed the product.
