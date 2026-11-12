# SAMANVAY Product Acceptance Matrix

**Product:** SAMANVAY — Know Below. Dig Above.  
**Purpose:** Integrated infrastructure coordination, underground asset governance and excavation-clearance platform.  
**Status convention:** “Implemented in code” is not the same as “verified in production”. Each feature must pass its stated tests and use authorised source data before being called complete.

## 1. Brand and shared application experience

- [x] SAMANVAY name, “Know Below. Dig Above.” product identity and shared application theme.
- [x] Inter application font and Space Grotesk display typography are configured.
- [ ] Final production logo/emblem, splash-screen artwork and onboarding sequence from approved brand assets.
- [ ] Accessibility review: contrast, text scaling, screen-reader labels, touch-target dimensions and reduced-motion behaviour.
- [ ] Common loading, retry, offline, empty-data and permission-denied states across all modules.

## 2. Citizen / requester mobile application

- [x] Supabase authentication and role-based portal selection.
- [x] New infrastructure request flow with location selection and case details.
- [x] Request list, case workspace, attachments and notifications foundations.
- [x] Requester dashboard with live case counts and case-category distribution.
- [ ] Full request workflow: saved draft, submission receipt, department assignment, multi-department review, clearance decision, work commencement, completion and closure.
- [ ] Citizen-visible active works by locality/ward, responsible agency, proposed dates, progress and current notices.
- [ ] Public complaint / obstruction report flow with moderation, duplicate handling and officer assignment.
- [ ] Public savings and avoided-repeat-digging figures calculated from verified completed work records.

## 3. GIS workspace

- [x] MapLibre vector basemap and provider attribution.
- [x] Current-device GPS centring, manual navigation, compass, zoom and 2D/3D camera transitions.
- [x] Visible work-request markers filtered by Supabase row-level security.
- [x] Request markers are colour-coded by case status.
- [x] Search UI for place, locality, ward or road using MapTiler Geocoding; requires a configured MapTiler key.
- [x] 3D building extrusion from the active vector basemap where the provider exposes building-height attributes.
- [x] Map scale calculated from current camera zoom and latitude.
- [x] Generalised utility-coverage query refreshes after the map viewport settles while the layer is enabled.
- [x] Generalised 250 m utility-coverage cells for authorised staff; exact utility geometry is not returned by this mobile view.
- [ ] Per-domain authoritative overlays: water, sewerage, stormwater, electricity, telecom, gas, roads, public works and permits.
- [ ] Search by municipal ward code, asset identifier or work-request number with role-appropriate results.
- [ ] Selected request detail panel, operational legend, date/status filters, map export and print view.
- [ ] Spatial query telemetry, refresh timestamps, visible-extent metadata and explicit stale-data indicators.
- [ ] Desktop/tablet GIS operations console with persistent layer manager, map canvas, analytics and alerts.

## 4. Underground asset registry and clearance

- [x] PostGIS underground asset and survey-evidence tables exist.
- [x] Asset-owner and survey evidence registration functions exist in the database.
- [x] Owner-side geometry access restrictions and mobile exact-geometry restrictions exist.
- [x] Generic request-level proximity/clearance advisory function exists.
- [ ] Utility-owner onboarding, data-sharing authorisation, data agreements and accountable dataset custodians.
- [ ] Import pipeline for verified CAD/GIS/GeoJSON/as-built records with source lineage, coordinate reference checks, duplicate detection and quarantine.
- [ ] Survey validation: method, survey date, horizontal/vertical accuracy, organisation, evidence, reviewer and verification decision.
- [ ] Owner-controlled exact-geometry operations console; no unauthorised requester/public access.
- [ ] Clear distinction between verified, owner-confirmed, field-surveyed, estimated, disputed, retired and unknown records.
- [ ] Empty coverage must never be presented as proof that the ground is clear or safe.

## 5. Coordination, clearance and clash detection

- [x] Multi-domain case categories and department service-domain routing foundation.
- [x] Department assignment/review and role-gated staff case workspace.
- [x] Current GIS utility-proximity check records a generic case-level advisory.
- [ ] Spatial + date-window conflict detection between overlapping planned/active work requests.
- [ ] Joint-work recommendation workflow with department responses, scheduling and authorised final decision. (Flutter workflow and SQL migration are committed; production acceptance remains pending database deployment and role-based runtime tests.)
- [ ] Clearance gateway with pre-work checks, dependencies, escalation and auditable approvals.
- [ ] Configurable no-dig / road-restoration / moratorium rules sourced from the responsible authority, with effective dates, exceptions and citations.
- [ ] Conflict review screen with evidence, affected work streams, decision history and officer actions; no invented collision visualisations.



Implementation note (2026-11-10): The joint-work coordination page, role-checked RPC migration and Android/browser build integration are present on `feature/alpha-03-integrated-platform`. The connected Supabase migration operation was rejected in a read-only transaction, so the new tables and RPCs are not confirmed deployed. Keep this acceptance item unchecked until the migration is applied and tested using coordinator, participating department and non-participant accounts.

## 6. Field inspection and as-built evidence

- [x] Private case evidence upload with file-type/size constraints and private storage.
- [x] Inspection record foundation with inspection type, outcome, officer and notes.
- [ ] Field-inspection mode with assigned permit/case, pre-work / progress / post-work stages and offline-safe draft capture.
- [ ] Geotagged field photos with capture timestamp, coordinate accuracy, device location provenance and tamper-evident audit.
- [ ] Planned-versus-observed depth entry only for authorised owner-side survey staff and only with traceable measurement evidence.
- [ ] As-built submission, survey quality checks, map calibration, owner review and controlled registry update.
- [ ] Incident / obstruction reports with escalation, evidence and closure confirmation.

## 7. AI support

- [x] Supabase Edge Function for case triage, summaries and coordination suggestions.
- [x] Staff authentication and department-assignment checks in the AI service.
- [x] AI assessment audit table and per-user request limit.
- [ ] Configure and verify the OpenAI API key and approved model in Supabase Function secrets.
- [ ] Interactive assistant interface with conversation/session handling and user-visible limitations.
- [ ] AI-supported cross-case conflict triage, missing-information checks and joint-work suggestions.
- [ ] AI outputs must include rationale, confidence/uncertainty and source context; an authorised officer must accept or reject them.
- [ ] AI must not approve permits, make statutory/legal determinations, certify utility locations or declare a site safe.

## 8. Executive analytics, alerts and audit

- [x] Staff portals and department service-domain analytics foundation.
- [x] Realtime notification and audit foundations exist in the database.
- [ ] Executive dashboard for active projects, pending clearances, delayed work and department workload.
- [ ] Avoided excavation, public-fund savings and coordination-rate metrics backed by recorded baseline assumptions and completed outcomes.
- [ ] Conflict alerts with severity, timestamps, responsible departments and resolution state.
- [ ] Searchable audit history for approvals, assignments, role changes, evidence, map-data updates and administrative actions.
- [ ] Exportable periodic reports and data-quality indicators.

## 9. External dependencies and blockers that cannot be fabricated

1. **Satellite imagery and geocoding:** valid MapTiler account/key, usage quota, permitted application usage and attribution. The key is a restricted client credential, not a Supabase service secret.
2. **Underground asset data:** written authorisation and validated records from the relevant utility owners / survey organisations. The checked GIS registry currently contains zero underground assets and zero survey-evidence records.
3. **AI service:** configure `OPENAI_API_KEY` and an approved `OPENAI_MODEL` in Supabase Edge Function secrets. Never embed this secret in Flutter or GitHub source.
4. **Public rules and notices:** authority-sourced road-restoration periods, moratoria, permits and notification content. No duration is to be hard-coded as universal law.
5. **Production release:** Android signing credentials, privacy/security review, device QA, accessibility checks, operational support and approved data governance.

## 10. Release acceptance gates

- [x] Static analysis passes with no errors on the latest map integration commit (Android and browser CI analyzers).
- [ ] Release APK builds and passes package/signature integrity diagnostics.
- [ ] Runtime smoke tests pass on a real Android device for sign-in, GPS permissions, map load, map search, 2D/3D, layer toggles, request submission and upload.
- [ ] Role tests confirm requester, department, coordinator and admin boundaries.
- [ ] Negative security tests prove requester/public users cannot retrieve exact underground geometries or survey evidence.
- [ ] Empty GIS data, no-permission and offline states are tested and worded safely.
- [ ] A utility owner validates imported records and their accuracy before any route is presented as verified.
- [ ] AI service is tested against the live configured model; missing/failed AI credentials produce a safe disabled state.
- [ ] The app is not called production-complete until all required items above are signed off.

**Current note:** This project remains an Alpha build. Items marked complete are implementation foundations, not production certification. The supplied UI images are design references; their sample counts, locations, clashes, dates and savings are not SAMANVAY production data.

## Additional browser-portal target

- [x] Dedicated GitHub Actions workflow to compile the Flutter app for the browser and package a static deployment artifact.
- [ ] Browser build must pass analysis and production compilation.
- [ ] Validate role-based login, GIS interaction, responsive layout, file upload and redirect URLs in a real WebGL2 browser.
- [ ] Deploy the static bundle to an approved HTTPS host and configure Supabase Auth redirect allow-lists for the production domain.
- [ ] Browser portal is the desktop operations target; MapLibre Flutter does not provide native Windows/macOS/Linux desktop targets.

## 11. India-wide data interface update — 6 November 2026

- [x] State/UT selector backed by the 36-row national jurisdiction directory.
- [x] Groundwater dashboard queries published observations by selected State/UT rather than hard-coding Coimbatore.
- [x] GIS groundwater layer now loads latest imported monitoring-station points across all currently represented States/UTs rather than filtering to Coimbatore.
- [x] Selected-jurisdiction CGWB 2025 resource metrics are shown separately from station telemetry.
- [x] National data-readiness panel summarizes coverage states for groundwater, utility GIS and building approvals.
- [x] Missing telemetry is shown as unavailable; it is not represented as zero groundwater or a safety clearance.
- [ ] Build workflow must complete successfully against the updated 398 KB Flutter entrypoint; this commit has been submitted for CI.
- [ ] Full UI/device, auth-role and GIS map regression testing remains outstanding.

## 12. Alpha 0.3 release verification — 6 November 2026

- [x] Flutter static analysis passed with informational lints non-fatal; no Dart errors.
- [x] Android release APK compiled successfully.
- [x] APK package, signature and alignment verification passed.
- [x] APK artifact uploaded: `SAMANVAY-Alpha-0.3-APK`.
- [x] Browser operations portal compiled and packaged successfully.
- [x] Building-approval portal/service entrypoints synced for 33/36 State/UT jurisdictions.
- [ ] Full Android device regression, role-based workflow testing, realtime notification testing and map interaction QA remain outstanding.
- [ ] Nationwide underground utility geometry and original building approval registers remain authority-data dependencies; not represented as completed by portal discovery.

## 13. Public-record and utility-source ingestion — 6 November 2026

- [x] Import 2,015 non-personal public MCD 2023 plan-release entries into `public.building_approval_public_register_records`, with 2,015 unique source request IDs.
- [x] Preserve source provenance and omit applicant/professional names, licence numbers and contact details.
- [x] Export the imported fields to `data/imports/mcd_public_building_plan_releases_2023.csv`.
- [x] Add a building-compliance UI panel showing the latest imported MCD entries and an explicit MCD-only/partial coverage warning.
- [x] Register 11 official public utility GIS service summaries across Andhra Pradesh, Kalyan-Dombivli and an FMDA-labelled OneMap service; aggregate raw feature count 658,896.
- [x] Restrict the detailed utility source registry to admin-only access. The public catalogue contains aggregate availability metadata only.
- [ ] Do not enable detailed utility geometry until the asset owner confirms data-sharing rights, currentness, survey provenance, coordinate reference system and positional accuracy.
- [ ] Obtain CCMC/TWAD commissioned as-built utility GIS for Coimbatore; the available project reports are not a current citywide as-built export.
- [ ] Expand original building-approval record imports beyond MCD; 2,015 records do not constitute a nationwide approval register.
- [ ] Recover the eight MCD source serial entries not reliably parsed from the public report extraction.
- [ ] Map the remaining three State/UT direct building-approval service entrypoints and obtain authority exports/API permissions for the mapped jurisdictions.


## 14. Nationwide infrastructure coverage explorer — 6 November 2026

- [x] Expand the national coverage-domain constraint from 3 to 10 infrastructure domains.
- [x] Populate 360 state/domain coverage metadata rows across all 36 State/UT jurisdictions.
- [x] Add roads/right-of-way, drinking water, sewerage/wastewater, stormwater, electricity, telecom/fibre and city-gas coverage categories.
- [x] Preserve national source references and responsible-authority/custodian descriptions.
- [x] Mark the new state/local registers as pending until the relevant custodian is confirmed.
- [x] Keep operational_use_allowed=false for all coverage rows; the explorer must not present coverage metadata as excavation clearance.
- [x] Add Flutter India navigation tab with State/UT search, jurisdiction selector, domain filter, source links and readiness labels.
- [x] Add an entry point from the operations portal national-readiness panel.
- [x] Add a reproducible SQL seed/update script at database/seed/india_nationwide_coverage_domains.sql.
- [ ] Identify and verify the responsible State/UT department, DISCOM, utility owner or ULB for each domain and jurisdiction.
- [ ] Secure owner-approved data-sharing terms and retrieve source records where lawful and permitted.
- [ ] Validate public-record completeness, update dates and record provenance; do not treat source discovery as data import.
- [ ] Complete role-based, Android-device and browser UI regression tests after the Flutter build.
- [ ] Keep sensitive underground network geometry in authority-controlled access workflows; do not expose precise routes, depths or asset-point details in the general explorer.

**Verified database state on 6 November 2026:** 360 coverage rows; 36 jurisdictions; 10 domains; 0 rows operationally enabled. The 360 rows are coverage metadata, not 360 downloaded or authority-verified datasets.


## 15. India administrative hierarchy and LGD import — 6 November 2026

- [x] Register Ministry of Panchayati Raj LGD as the national administrative hierarchy source.
- [x] Expand the coverage matrix to 11 domains across all 36 States/UTs (396 coverage metadata rows).
- [x] Create administrative-unit hierarchy table with unique LGD code, parent unit, source date and verification status.
- [x] Create import-batch audit table with report provenance and row counts.
- [x] Apply authenticated read and admin/coordinator management RLS.
- [x] Add district/ULB readiness panel to India coverage explorer.
- [x] Add admin/coordinator-only CSV import screen with required-column validation, State/parent checks and text-preserved LGD codes.
- [x] Link a single-State CSV upload to its matching queued district/ULB export batch; keep multi-State uploads separately audited.
- [x] Add CSV parser to Android build workflow.
- [x] Register the official IGOD State/UT district index and state-specific district-page URLs.
- [x] Create 36 district export tasks and 36 urban-local-body export tasks in the import-batch audit table.
- [x] Mark all 36 administrative-directory coverage rows as CAPTCHA-required / export pending.
- [x] Show pending district and ULB export task totals in the admin/coordinator India explorer panel.
- [x] Add reproducible queue SQL at database/seed/india_lgd_export_queue.sql.
- [ ] Generate/download official LGD reports through the normal portal CAPTCHA flow.
- [ ] Import district, sub-district, block, ULB, panchayat and ward records with source dates.
- [ ] Verify current local-body records against the State/UT authority and LGD revision history.
- [ ] Complete Android/browser build and device regression checks.
- [ ] Populate official State/UT and ULB department contacts and source registers.
- [ ] Obtain owner-authorised, current public/permission-based infrastructure datasets; keep detailed utility geometry in authority-controlled workflows.

**Verified database state on 6 November 2026:** 396 coverage metadata rows; 36 jurisdictions; 11 domains; 0 administrative hierarchy records imported; 72 export batches queued (36 districts + 36 ULBs); all 72 awaiting authorised report generation; 0 operationally enabled coverage rows. No district or ULB records have been fabricated.


## 16. Restricted asset verification centre — 6 November 2026

- [x] Create admin/coordinator-only metadata view for underground asset review.
- [x] Exclude geometry, coordinates, depth, dimensions and positional accuracy from the view.
- [x] Include verification status, source type, owner department, survey date and evidence count.
- [x] Add evidence lookup index.
- [x] Add Flutter review screen with status filter and role check.
- [x] Add navigation from the India coverage panel for authorised roles.
- [x] Add reproducible SQL at database/seed/asset_verification_queue.sql.
- [ ] Receive current owner-authorised asset metadata and survey evidence.
- [ ] Validate provenance and evidence under the asset owner's process.
- [ ] Keep detailed geometry in the authority-controlled GIS workflow, separate from the general app.

**Verified current data:** 0 underground asset records and 0 survey evidence records. The verification centre is implemented but has no submitted assets to review.


## 17. National authority directory — 6 November 2026

- [x] Create national authority directory with role, responsibility, domain tags and official source links.
- [x] Seed nine central/national directory, ministry, programme, technical-body and regulator references.
- [x] Add authenticated read and admin/coordinator management RLS.
- [x] Add domain index for filtering.
- [x] Add Flutter searchable authority directory page and link it from the India coverage explorer.
- [x] Explicitly mark local custodian confirmation as required for all national reference entries.
- [ ] Resolve the actual State/UT department, ULB, utility owner or regulator for each jurisdiction/domain.
- [ ] Add verified local agency portal and data-sharing references once confirmed.
- [ ] Obtain and validate source registers and their update dates.

**Verified database state:** 9 national authority references. This is an authority/source directory, not a complete list of every State/UT or municipal department.

## 18. Surface 3D and underground GIS operating modes — 7 November 2026

- [x] Add a dedicated Surface / Underground mode selector to the MapLibre GIS workspace.
- [x] Preserve vector/satellite basemaps and independent 2D/3D camera controls.
- [x] Render contextual 3D building extrusions only where the selected basemap supplies building geometry and height attributes.
- [x] Suppress surface building extrusions and administrative outlines in Underground mode.
- [x] Load generalised 250 m underground-coverage cells only for authenticated infrastructure staff with the existing role gate.
- [x] Load exact verified asset geometry only through the assigned-department RPC; other departments' exact geometry remains withheld.
- [x] Keep requester accounts out of operational underground geometry and show an explicit permission/coverage explanation.
- [x] Add map-side readiness summaries for groundwater, building approvals and utility-GIS coverage.
- [x] Refresh published groundwater station points against the visible map extent (maximum 1,000 features per viewport) and show the stored reading text/value and observation timestamp.
- [x] State explicitly that an empty map, missing warning or generalised coverage cell is not excavation clearance.
- [ ] Implement true volumetric underground 3D / subsurface cutaway rendering using owner-authorised depth, vertical datum, geometry and survey-accuracy metadata. The current underground mode is an authorised 2D GIS overlay on a navigable map, not a fabricated 3D utility model.
- [ ] Receive and validate asset-owner utility GIS, survey evidence and data-sharing permission before enabling operational asset layers.
- [x] Complete Android APK compilation, package/signature/alignment checks and release artifact publication on integrated commit `e05753da08285c4cee4fb16bdf6aa5b22c12309a`; the ULB browser correction is included in that tree.
- [ ] Run real-device Android map tests and browser GIS regression tests for Citizen, Department Officer, Coordinator and Administrator roles.
- [ ] Receive geocoded building approvals and approved floor/height values before plotting approval records or performing map-based compliance analysis.

**Implementation commit:** `2a13790554d32cd4bc6b963b8dea554d98746d70` on `feature/alpha-03-integrated-platform`. Follow-up map-style visibility fix: `5e3ebe1bd430f00c56632765db216c5f19fee4ee`. Dart analysis passed on Android and browser workflows; browser compilation and packaging completed. Android APK compilation was still running at the time of this matrix update. The 3D basemap building extrusions are contextual OSM-derived massing, not statutory approval heights. Utility coverage metadata and empty registries do not establish that underground infrastructure is absent.


## Public excavation tracker foundation — 9 November 2026

- [x] Add a citizen-facing published-notice search by city, district, ward, area and notice code.
- [x] Add authority-published work and no-dig notice cards with responsible department, date window, sourced progress and timeline.
- [x] Add obstruction reporting with reporter-scoped records and department/admin review boundaries.
- [x] Add RLS policies that expose only published notices and their public timeline; obstruction reports remain private to the reporter and authorised reviewers.
- [ ] Apply the migration to the connected Supabase project and run role-based RLS tests.
- [ ] Publish the first source-backed notice from an authorised department and verify it appears in the public tracker.
- [ ] Validate notice event updates, assignment and moderation workflow in the browser and Android app.

**Implementation boundary:** No public notices or obstruction reports are preloaded. The tracker is intentionally empty until an authorised publisher supplies a source reference and publishes a record. A no-dig notice or empty search is not excavation clearance.


## 19. GSI / NWIC administrative boundary reference catalogue — 12 November 2026

- [x] Register GSI/NWIC State and Union Territory boundary metadata.
- [x] Register GSI/NWIC sub-district boundary metadata with its published 6,312-feature count and 5 May 2025 source date.
- [x] Register the State/UT-wise village boundary catalogue, including the Tamil Nadu resource link and its published 2 May 2025 source date.
- [x] Preserve each resource as metadata-only and explicitly record that the open licence label is not a complete licence/permission review.
- [x] Record the 6,312 NWIC sub-district feature count versus 7,092 LGD community-mirror rows as a mandatory reconciliation issue.
- [ ] Download each relevant State/UT archive through the published access route and retain archive hashes.
- [ ] Validate file format, CRS, geometry validity, topology, coverage and source attributes.
- [ ] Reconcile boundary features to current LGD codes using stable source identifiers; do not use fuzzy name matching as an authority link.
- [ ] Import only the validated reference geometry with source lineage, vintage and non-statutory status.
- [ ] Confirm complete State/UT coverage, especially State-wise village resource availability.

**Live validation:** Three GSI/NWIC source rows are present in `public.official_data_sources` with `integration_status = 'metadata_registered'`. No NWIC boundary geometry has been imported. The persisted 733 district polygons remain DataMeet-derived historical references. The active directory contains 784 district, 7,092 sub-district, 7,312 block and 5,050 ULB LGD-code-bearing community-mirror rows; every one remains unverified. ULB district-parent links: 0; ward rows: 0; village rows: 0. The Phase 2 software must preserve these distinctions.

## 20. Phase 2 database security hardening — 12 November 2026

- [x] Convert `public.utility_asset_verification_queue` to PostgreSQL invoker security while preserving its security-barrier option.
- [x] Grant authenticated read access only to the queue's base relations that are needed by the view.
- [x] Add admin/coordinator-only SELECT RLS to `gis.underground_assets`, `gis.asset_survey_evidence` and `public.utility_geometry_import_runs`.
- [x] Add explicit deny policies for anon/authenticated access to internal AI-usage, groundwater-import and utility-review event logs; service-role ingestion remains server-managed.
- [x] Set `public.publish_highway_work_notice(uuid,text,text,smallint)` to an empty search path. Its existing authentication, department ownership and role checks are retained.
- [x] Verify the view now has `security_invoker=true`; verify all 6 formerly policy-less tables now have policies.
- [x] Verify `anon` cannot execute the 15 application-facing security-definer RPCs; authenticated RPC calls remain because the app uses these role-checked operations.
- [x] Align repository migration filenames with the exact two versions recorded by the connected Supabase migration ledger.
- [x] Run authenticated-role SQL smoke tests: Admin directory, Coordinator advisory, Department-owned-geometry endpoint and Citizen generalised-GIS endpoint all returned expected role-scoped results; a Citizen session was blocked by six privileged staff/admin RPCs. Tests ran inside rolled-back transactions and created no records.
- [ ] Repeat positive/negative access tests with non-empty owner-authorised utility records and survey evidence; current GIS asset/evidence tables are empty, so this remains unverified.
- [ ] Enable Supabase Auth leaked-password protection in the project Auth settings; this setting is not exposed by the connected database migration interface.
- [ ] Re-run Android/browser CI and complete real-device/browser role regression after the current migration commits.

**Live security advisor result:** The `security_definer_view` finding is cleared and the six `rls_enabled_no_policy` findings are cleared. Remaining notices: 15 authenticated-executable security-definer RPC warnings (these are intentional app endpoints and remain subject to their internal role checks), plus one Auth warning because leaked-password protection is disabled. One RPC search-path exception identified in the audit has been corrected. This does not constitute a full penetration test or production-security certification.

## 21. India-first map defaults and national coverage honesty — 12 November 2026

- [x] Keep the no-explicit-location map fallback centred on India (22.5° N, 79.0° E); an explicit device GPS fix or a feature-specific selected location may still override it.
- [x] Change the 2024 Coimbatore ward reference overlay to opt-in; do not load its local GeoJSON when the toggle is off.
- [x] Relabel the layer as “Coimbatore-only ward reference (2024)” and show its local-reference / non-statutory / non-national status.
- [x] Remove the prefilled Coimbatore city from the public-work notice form; require the publisher to enter the actual notice city and show examples spanning North and South India.
- [ ] Validate map navigation and overlay toggles on a physical Android device and browser at national, State/UT, district and local zoom levels.
- [ ] Import authority-validated national and local boundaries after archive retrieval, checksum, CRS/topology QA and LGD-code reconciliation.

**Implementation commit:** current source contains the no-default ward toggle, conditional layer loading and national default camera. Android and browser CI were triggered for the updated source; their final build and artifact verification must pass before this section is release-accepted.
