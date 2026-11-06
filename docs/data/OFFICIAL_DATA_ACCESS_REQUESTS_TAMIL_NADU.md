# Official data access request pack — Tamil Nadu / Coimbatore

These are request templates for SAMANVAY's project team to submit through the official office channel. They have not been sent by SAMANVAY.

## A. To Coimbatore City Municipal Corporation — City Engineer / Engineering Department

**Subject: Request for authorised GIS asset data for coordinated underground utility management**

We are developing SAMANVAY, a civic infrastructure coordination platform intended to reduce repeated road excavation, utility clashes and uncoordinated restoration work.

We request guidance on whether CCMC can provide, or formally authorise access to, the latest available digital asset records for Coimbatore Corporation limits:

1. Drinking-water transmission and distribution mains, valves, reservoirs, pumping stations and related structures.
2. Underground sewerage networks, manholes, pumping stations and treatment-system connections.
3. Stormwater drains, culverts, outfalls and related structures.
4. Road centreline / road-edge and ward boundary layers needed for spatial referencing.
5. Existing 24/7 Water Supply project volumes and the latest approved/as-built drawings for the Siruvani, Pillur, Aliyar and Bhavani distribution systems, including storage reservoirs and interconnecting mains.
6. Current Asset Management System exports and any GIS study data originally prepared for CCMC, including the status of AutoDCR/GIS/asset-management integration.

Preferred formats: GeoPackage, GeoJSON, Shapefile, KML/KMZ or CAD (DWG/DXF), with the coordinate reference system and a data dictionary.

For each asset, if available, please include a stable asset ID, type, owning/maintaining department, geometry, material, diameter/dimensions, depth/invert level, operational status, installation/last-inspection date, survey method, positional accuracy, source/record date and any access restrictions.

Please clarify which records are authoritative and current; whether geometry is suitable for excavation-planning use; required attribution, licence, security controls and permitted reuse; whether sensitive layers must be accessed only by authorised departmental users; and the process for reporting corrections and receiving periodic updates. For TNUFIP Tranche 1 (Kurichi/Kuniyamuthur) and Tranche 3 (Vadavalli, Veerakeralam, Kavundampalayam and Thudiyalur), please identify the project implementation unit and provide final as-built CAD/GIS, manhole register, invert levels, lift/pumping station locations, completion certificates, commissioning dates and contractor handover records, not only draft IEE or design drawings.

We will preserve source attribution and will not expose sensitive utility geometry to the public.

## B. To CCMC Town Planning / Executive Engineer (Planning)

**Subject: Request for authorised building-plan approval verification data for compliance inspection**

We request a controlled integration method for verifying building observations against official approvals within Coimbatore Corporation limits.

Requested fields, subject to applicable privacy and disclosure rules:
- Application/service-request number and building permit/approval number;
- Approval authority and issuing office;
- Approval date, validity/current status and revised/cancelled status;
- Property/parcel identifier, survey number and approved site location/geometry;
- Sanctioned plan document reference and secure document retrieval method;
- Permitted floor/unit schedule and approved building height;
- Inspection/completion/occupancy status where legally disclosable;
- Data update timestamp and correction/revision history.

A documented API, bulk extract, verification endpoint or nominated officer workflow would be preferred. The public portal has individual building-plan search and approval-number pages, but this review did not establish a reliable Coimbatore-only bulk export. Please identify the authoritative Coimbatore ULB records custodian and provide a scoped export or verification endpoint. Please specify which fields may be used for civic coordination, which must remain restricted, and the permitted retention/sharing terms.

SAMANVAY will treat discrepancies as review flags only; statutory determinations remain with the competent authority.

## C. To TNeGA / TNGIS

**Subject: Request for access, ownership and reuse conditions for Coimbatore utility and planning GIS layers**

Please identify TNGIS applications/layers covering Coimbatore that contain water supply, underground drainage, stormwater, roads, building footprints, planning zones or public utility assets.

For each layer, please provide the owning department and designated data custodian; dataset title, coverage, scale/resolution, CRS and last update; API/download/service endpoint and technical access method; data dictionary, positional accuracy and known limitations; licence, attribution and approval requirements for use in a non-commercial civic prototype and any future operational deployment; and whether written permission from the source department is additionally required.

We will not redistribute or commercially use any restricted layer without written permission.

## D. To Tamil Nadu Surface Water and Ground Water Department / NWIC

**Subject: Clarification request for NWDP groundwater telemetry data use**

We have identified the NWDP six-hourly Tamil Nadu SW GW telemetry resource. Please confirm the intended interpretation and sign convention of the published groundwater level field, station update cadence, station status/retirement conventions, timestamp timezone, coordinate reference system and permitted reuse/attribution requirements. Please also advise whether a station master list and historical data API are available.

## Submission checklist
- Submit from the project's authorised email or official letterhead.
- Do not include private applicant details or personal property records in a public request.
- Retain the acknowledgement, permission letter, source files, data dictionary and version/date of receipt.
- Do not import restricted data until the data custodian confirms permitted access and use.
