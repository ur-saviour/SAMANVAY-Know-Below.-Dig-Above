# SAMANVAY India-wide Data Readiness Audit — 7 November 2026

**Branch:** `feature/alpha-03-integrated-platform`  
**Database:** Supabase project `zhtotivedvkmclerdnlf`  
**Audit method:** Read-only live database queries and repository document inspection.  
**Purpose:** Separate operational imports from source catalogues, coverage metadata and unresolved authority access.

## Executive result

The national data foundation is materially populated, but the India-wide underground-utility and building-approval objectives are **not complete**. The database contains useful groundwater observations and a limited Delhi public building-register extract. It does not contain operational underground utility geometry or a nationwide building-permission register.

## Live database snapshot

| Area | Live count | What this establishes | What it does not establish |
|---|---:|---|---|
| States / UTs directory | 36 | All 36 State/UT master entries exist | District, ULB, ward or village hierarchy is imported |
| India data-coverage metadata | 396 | Coverage metadata records exist (36 × 11 domains) | Operational data exists for every domain |
| India administrative units | 0 | — | LGD hierarchy is not imported |
| Groundwater state assessments | 36 | State-level assessment rows exist | Current monitoring observations for every State/UT |
| Groundwater district assessments | 199 | District assessment rows exist; validation label is `row_crosschecked_not_aggregated` | These are not all districts and are not a substitute for well-level measurements |
| Groundwater station observations | 1,360,063 | Observation records are present | The row count alone does not establish freshness, completeness or uniform coverage |
| Station observations with coordinates | 1,359,548 | Most observation rows have coordinate fields | Coordinates still require source accuracy and station-level QA before operational siting |
| Station observations missing coordinates | 515 | Missing-coordinate records are quantifiable | They must not be silently plotted |
| Groundwater observation register | 0 | — | No separate field-observation records have been submitted through the operational register |
| Groundwater import-run audit table | 0 | — | Existing station rows have not been recorded through this import-run audit table |
| Building public-register extract | 2,015 | Public-register records extracted for Municipal Corporation of Delhi | Not a nationwide approvals dataset |
| Building operational approval records | 0 | — | No owner-authorised building approvals are registered in the operational table |
| MCD building records with geometry | 0 / 2,015 | None are geocoded in this register | No parcel-level spatial compliance checks can be claimed |
| Restricted utility source registry | 11 | Source/authority metadata entries exist | Not 11 operational utility layers |
| Utility layer catalogue | 125 | Layer catalogue entries exist | Catalogue entries are not accepted feature geometries |
| GIS underground assets | 0 | No exact utility asset geometry is registered | Does not mean utilities are absent |
| GIS asset survey evidence | 0 | No field survey evidence is attached | No utility asset can be field-verified from this table |

## Coverage and integrity findings

### 1. Groundwater

- The database has 36 State/UT assessment entries and 199 district assessment rows.
- The station-observation table contains 1,360,063 rows. Observations are represented under 30 state/UT labels in the live grouped query; do not describe this as uniform 36/36 telemetry coverage.
- 515 observations have no latitude or longitude and must remain excluded from map plotting until corrected from the source.
- The separate import-run audit table is empty. Preserve source URLs, station identifiers, import timestamps and checksums in the next ingestion reconciliation.
- District assessment rows carry `row_crosschecked_not_aggregated`; this is not an official validation certification.

**Status:** National groundwater reference/observation data is substantially populated. A complete, current, all-State/UT monitoring feed and an auditable import ledger remain outstanding.

### 2. Utility GIS

- 11 restricted source registry entries and 125 layer-catalogue entries exist.
- `gis.underground_assets` and `gis.asset_survey_evidence` both contain zero rows.
- The GIS ingestion specification correctly requires owner-provided or authorised survey data, explicit permissions, provenance and review before verification.
- National basemaps, ward boundaries, satellite imagery, waterbody layers and metadata catalogues must not be converted into invented buried utility alignments.

**Status:** Discovery and governance catalogue are in place. Operational utility GIS is blocked on authorised asset-owner data and/or approved survey evidence. This cannot be solved by fabricating geometry or treating portal metadata as an import.

### 3. Building approvals

- The public-register extract contains 2,015 records, all attributed to the Municipal Corporation of Delhi.
- Extracted approval-status labels are 45 “Fresh Plan - Plan Released”, 911 “Sanction Upto 500 sqm - Plan Released”, and 1,059 “SARAL - Plan Released”.
- All 2,015 records are marked `official_public_register_extracted`, but none is geocoded.
- The operational `building_approval_records` table contains zero records.
- The 396 coverage metadata entries show state/UT portal discovery and access statuses; these do not mean approvals were acquired from all authorities.

**Status:** A limited Delhi public-register extract exists. Nationwide official approval records, parcel/plot linkage, sanctioned floor counts/heights, revisions, completion/occupancy certificates and enforcement history remain incomplete. Do not infer sanctioned floors from plan category or public text.

## Acquisition blockers that require an external authority

1. **Utility GIS:** Each water, sewer, stormwater, electricity, gas and telecom asset owner must provide the approved data, schema, CRS, accuracy, update date, licence/permission and secure transfer route.
2. **Building approvals:** Each competent planning authority/ULB/state portal must provide an authorised export or documented API access. Public portal visibility does not guarantee bulk extraction or reuse rights.
3. **LGD administrative hierarchy:** Bulk export currently records `captcha_required_for_bulk_export` for 36 jurisdictions. Use the official authorised export/API route; do not bypass CAPTCHA or automate around access controls.
4. **Groundwater:** Reconcile imported observation resources to their official publisher, release date, station coverage, units, source row counts and import-run audit records. Exclude stale, malformed and coordinate-deficient rows from operational displays.

## Required product safeguards

- Keep groundwater observations, district assessments, utility geometry and building approval records as separate data classes.
- Every record must preserve publisher, custodian, jurisdiction, source identifier, source URL/document, dataset version, date, CRS/units, licence/permission and import batch.
- Keep exact utility geometry private and owner-scoped. Generic administrator access must not imply access to all critical infrastructure.
- Do not expose unverified, stale, estimated or disputed records as operational truth.
- Show missing data as “not available / not authorised / not imported”, never “no asset exists”.
- Clash alerts and building-compliance flags are advisory; statutory decisions remain with the competent authority.

## Next workstream — Evidence and document management

The data-acquisition work now has a reproducible baseline and explicit blockers. The next implementation workstream should be **Evidence and Document Management**, starting only after the current security findings are remediated:

1. Fix the security lints for RLS-enabled tables without policies, the SECURITY DEFINER view, mutable function search paths and unnecessarily exposed SECURITY DEFINER RPC execution.
2. Add case-linked evidence metadata for permits, sanctioned plans, as-built drawings, survey reports, photographs, inspection notes and authority correspondence.
3. Store files in private Supabase Storage buckets; enforce owner/department/case-scoped access and short-lived signed downloads.
4. Record uploader, source authority, document type, checksum, received date, validity period, verification state and reviewer decision.
5. Add audit events for upload, view, download, replacement, verification and revocation.
6. Keep AI document extraction as a draft-assistance feature; extracted values must retain page/source references and require human review before becoming official records.

## Acceptance gate

The data workstream is not “complete” until authorised source datasets have actually been received, validated and imported. The next feature must not bypass this gate or promote reference data into verified infrastructure records.

**Audit conclusion:** The current branch/database provides a useful national discovery and groundwater foundation, a Delhi-only public building-register extract and a utility metadata catalogue. It does not yet provide a nationwide, operationally verified underground utility map or nationwide building approvals database.
