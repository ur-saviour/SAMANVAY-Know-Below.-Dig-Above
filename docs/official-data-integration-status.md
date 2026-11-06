# SAMANVAY — Official Data Integration Status
Last verified: 6 November 2026 (IST)
Repository branch: `feature/alpha-03-integrated-platform`
Supabase project: SAMANVAY production-development project

## Executive result

SAMANVAY now contains an actual public building-plan release register import and a verified catalogue of public-government utility GIS services. This is a meaningful improvement over portal-only discovery, but it is not yet a fully populated nationwide authority asset register.

## 1. Building approval records — actual import completed (partial jurisdiction coverage)

**Imported:** 2,015 unique public MCD plan-release records.

- Authority: Municipal Corporation of Delhi (MCD).
- Source: MCD NexGen OBPS Plan Release Report (2023), served from the official MCD public download endpoint.
- Release dates represented: 1 June 2023 to 9 October 2023.
- Unique MCD request IDs: 2,015.
- Zones represented: 12.
- Fields imported: source serial, request ID, zone, building type/subtype, plot area, published approval/release status, public address, release date and source provenance.
- Applicant names, architect names, licence numbers and structural-engineer names were excluded from the import.
- Approved floor count, approved height and verified building coordinates are not present in the source report; these fields remain null/not geocoded.
- The extracted report serial range runs through 2,023; eight serial entries could not be reliably recovered from the source text extraction and were not fabricated or inserted.

Database table: `public.building_approval_public_register_records`.

Reproducible, non-personal CSV export:
`data/imports/mcd_public_building_plan_releases_2023.csv`.

Source portal: https://eodb.mcd.gov.in/

Original public report:
https://mcdonline.nic.in/portal/downloadFile/nexgenobpsreleasereport_240101031243143.pdf

**Coverage limitation:** This is MCD-only. It is not a complete Delhi-wide register, and it is not a national building-approval register. The national coverage matrix currently has 33 of 36 State/UT portal or service entrypoints mapped, but portal mapping does not mean that each jurisdiction's records have been imported.

## 2. Underground utility GIS — public services discovered and source counts verified

Eleven government utility GIS service layers have been registered in the admin-restricted source registry. Their aggregate feature counts were queried from the official services on 6 November 2026.

| Geography / service family | Utility themes | Raw service feature rows |
|---|---|---:|
| Andhra Pradesh State GIS services | Water supply, drainage, sewerage | 637,746 |
| Kalyan-Dombivli municipal GIS | Water, sewerage, stormwater, gas | 8,568 |
| FMDA-labelled OneMap service | Water, sewerage, stormwater | 12,582 |
| **Total across the listed services** |  | **658,896** |

These are raw feature-service counts, not a deduplicated count of unique physical assets. A feature count alone does not establish that every geometry is complete, current, field-surveyed or approved for operational use. The FMDA source's exact owning authority and geographic coverage still require confirmation.

**Geometry import status:** No detailed underground network coordinates or sensitive linework have been copied into SAMANVAY's operational asset table. The service metadata and aggregate counts are registered, with `operational_use_allowed=false`. Exact utility alignment, depth, valve/manhole positions and other detailed network attributes must remain under the competent utility owner's controlled access and security review. Public map availability is not a substitute for owner validation or permission to republish sensitive infrastructure details.

For Coimbatore specifically, CCMC/TWAD public project reports establish that sewerage schemes and engineering plans exist, but the documents located are project/environmental reports and design references—not a current, complete, surveyed, citywide as-built GIS export. The CCMC department page also describes the drainage/UGD service and publishes project reports:
https://www.ccmc.gov.in/index.php/department/ugd

The MoHUA engineering guidance explains that existing pipe networks should be mapped from commissioned as-built drawings and validated by appropriate survey methods; approximate routes should not be treated as known pipe locations:
https://mohua.gov.in/upload/uploadfiles/files/Manual-on-Water-Supply-and-Treatment-Systems-Drink-from-Tap-Part-A-Engineering.pdf

## 3. Database and access controls

- `gis.utility_layer_catalog`: 125 layer contracts; zero operationally enabled.
- `gis.restricted_utility_source_registry`: 11 source-layer metadata records; admin-only read/write policy.
- `public.building_approval_public_register_records`: 2,015 imported public register records; authenticated read, admin/coordinator write.
- `public.building_approval_records`: original structured approval schema remains available for verified authority records that include richer approval fields.
- `public.official_data_sources`: 53 source entries.

The utility registry stores service-level metadata and aggregate counts only. It does not store or expose detailed network geometries. No pending or estimated utility line is to be represented as a verified underground asset.

## 4. Current nationwide data context

| Dataset | Latest verified state |
|---|---:|
| State/UT master | 36 |
| CGWB 2025 State/UT assessment records | 36 |
| Groundwater telemetry observation rows | 1,360,063 |
| State labels represented in telemetry | 31 |
| District labels represented in telemetry | 166 |
| Telemetry resources (2021–2025) | 11 complete, 24 partial, 27 discovered/not imported |
| Building approval portal/service entrypoints | 33 / 36 |
| Actual public building-plan records imported | 2,015 (MCD only) |
| Operational utility geometry layers | 0 |

Telemetry resource feeds can overlap; imported row totals must not be described as a deduplicated national count without reconciliation.

## 5. Remaining authority-data requirements

1. Obtain current, owner-issued and authorised GIS/as-built exports for water, sewerage, stormwater, electricity, telecom and gas from the responsible utility owners. Each delivery needs a source licence/permission, coordinate reference system, survey/as-built date, positional accuracy, asset status, and custodian contact.
2. For Coimbatore, obtain CCMC/TWAD commissioned as-built GIS or CAD exports, including survey metadata and a written data-sharing permission. Project concept/design drawings alone do not qualify as as-built asset geometry.
3. Obtain building approval register exports or approved APIs from each State/UT planning authority and ULB. Preserve approval/request ID, authority, approval date/status, approved floors/height where present, plot/survey reference, source record and revision history. Do not scrape or retain applicant contact details.
4. Reconcile the eight MCD report serials that were not recovered in extraction, if a clean original workbook is supplied by MCD.
5. Geocode building records only from authoritative parcel/plot coordinates or an approved official GIS join; do not infer private residential coordinates from text addresses.
6. Validate every import before operational use. The app must distinguish source discovered, source retrieved, records imported, geometry validated, authority confirmed and field verified.

## 6. Nationwide infrastructure coverage explorer — 6 November 2026

The state/UT coverage matrix has been expanded from three domains to ten, covering the 36 State/UT jurisdictions listed by the National Portal of India / IGOD.

- **Coverage rows:** 360 (36 jurisdictions × 10 domains).
- **Existing domains retained:** groundwater, underground utility GIS and building approvals.
- **New nationwide coverage domains:** roads/right-of-way, drinking-water supply, sewerage/wastewater, stormwater drainage, electricity distribution, telecom/fibre and city-gas distribution.
- **National source references:** MoRTH, Jal Jeevan Mission / Department of Drinking Water & Sanitation, MoHUA CPHEEO, Central Electricity Authority, Department of Telecommunications and PNGRB.
- **State/local custodian resolution:** pending. The named national institutions provide sector-level policy, programme or regulatory context; they do not replace State/UT, DISCOM, utility-owner or ULB confirmation.
- **Operationally enabled coverage rows:** 0. No new coverage template is treated as a verified asset inventory or field-work clearance.
- **Access:** signed-in users can read the matrix; admins/coordinators retain management access through the existing RLS policies.

The Flutter interface now includes an **India** navigation tab and an operations-dashboard entry to the same explorer. It provides State/UT search, jurisdiction selection, infrastructure-domain filtering, authority/custodian descriptions, national-source links and explicit status labels. The explorer reads the live public.india_state_uts and public.india_data_coverage tables.

**Interpretation warning:** 360 rows represent coverage metadata templates, not 360 downloaded datasets. For the seven newly added domains, a row means that a relevant national-level source or sector authority has been identified and a State/UT or local asset register still needs to be confirmed and obtained. The explorer does not claim that all local portals, approvals, networks or as-built records have been collected.

Reproducible SQL:
database/seed/india_nationwide_coverage_domains.sql

Jurisdiction reference:
https://www.india.gov.in/directory/web-directory/state-uts

National urban water/sanitation/stormwater technical role:
https://www.mohua.gov.in/ministry/our-division/details/cpheeo-QDM1IzMtQWa

## 7. India administrative hierarchy and LGD import — 6 November 2026

The official Ministry of Panchayati Raj Local Government Directory (LGD) is now registered as the national administrative hierarchy source. It assigns unique LGD codes and covers State/UT, district, sub-district, block, urban local body, panchayat, village and ward entities.

**Source-access finding:** the public LGD portal exposes citizen views, but bulk report generation at https://lgdirectory.gov.in/downloadDirectory.do requires a CAPTCHA. The automation inspected the official workflow and stopped at the CAPTCHA; it did not solve, bypass or automate it. The OGD Platform's LGD local-body resource page also says its data is dynamically generated through API and that an API for that resource does not exist. The LGD district resource is listed as monthly updated, but a direct bulk download was not verified in this pass.

**Implemented:**
- Added `administrative_directory` as the 11th coverage domain across all 36 jurisdictions.
- Added `public.india_administrative_units` for the LGD hierarchy, parent-child links, unique LGD codes, source dates and verification status.
- Added `public.india_directory_import_batches` for report provenance, filename, report date, row counts and import audit.
- Added RLS: authenticated read for administrative units; admin/coordinator-only management; admin/coordinator-only access to import batches.
- Added an India explorer panel that shows the imported-record count, verification count and official LGD report link.
- Added an admin/coordinator-only CSV import screen. It validates required LGD Code, Name and State Name fields, preserves codes as text (including leading zeros), checks state/parent references, records report date and source filename, and upserts records with `imported_unverified` status. It never marks an import authority-verified.
- Added CSV parser dependency to the Android build workflow.

**Current verified database state:**
- Coverage metadata: 396 rows = 36 jurisdictions × 11 domains.
- Administrative hierarchy records imported: 0.
- Import batches: 0.
- Operationally enabled coverage rows: 0.

The 36 administrative-directory rows are source/readiness metadata, not 36 populated district or ULB lists. A report generated from LGD by an authorised operator is still required before district, municipality and ward records can be populated. The importer is intentionally limited to admin/coordinator roles.

Sources:
- Ministry of Panchayati Raj LGD overview: https://panchayat.gov.in/en/lgd/
- Official LGD report generator: https://lgdirectory.gov.in/downloadDirectory.do
- OGD LGD districts resource: https://data.gov.in/resource/local-government-directory-lgd-districts
- OGD LGD local bodies resource: https://data.gov.in/resource/local-government-directory-lgd-local-bodies

Reproducible schema/seed:
`database/seed/india_lgd_administrative_directory.sql`

## Operational rule

A public map layer, engineering diagram, approximate alignment, portal listing or aggregate feature count is not an excavation-clearance source. Pending utility layers must not be used for excavation clearance. Only owner-authorised, current and appropriately validated data may be promoted to operational use.
