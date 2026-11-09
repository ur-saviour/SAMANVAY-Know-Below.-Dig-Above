# SAMANVAY Alpha 0.3 — Implementation and Verification Report

**Date:** 9 November 2026  
**Repository:** `ur-saviour/SAMANVAY-Know-Below.-Dig-Above`  
**Branch:** `feature/alpha-03-integrated-platform`  
**Implementation snapshot before this report:** `b61e8a07d59eea8dfb842c2d7ffb36243990ed85`

## Executive status

A scoped implementation pass is committed. The current state is **partially implemented, not a completed national deployment**.

The pass delivers a refreshed mobile navigation/theme shell, a data-backed account profile, a public works tracker, private obstruction reports, tighter database grants, a dark vector-map default, and the Android namespace correction. The public tracker migrations are applied to the existing Supabase project and their database grants were queried directly.

The browser portal build and packaging passed on application source commit `7c463725978eae276064738e392b27ee2c4722bc`. A later Android run for that same application source passed dependency installation and Dart analysis but remained in the release APK build step at the time this report was authored. Therefore **no latest-source APK is claimed as verified**.

## Commits on the implementation branch

| Commit | Change |
|---|---|
| `c94c952d9e473e72a067a19ebd8c31672cc772ac` | Theme/navigation, profile replacement, public tracker, Android namespace fix, CI copy steps and initial tracker migration |
| `496261f7c7d2fe3490abf6c54aa33ebf3af065d5` | Split public and staff draft-read policies; restrict report update fields |
| `c78c45ae05804185cc3e4cac3faaa16567f665b7` | Add public tracker entry from sign-in and private evidence viewer |
| `7c463725978eae276064738e392b27ee2c4722bc` | Latest application source used for browser and Android CI |
| `b61e8a07d59eea8dfb842c2d7ffb36243990ed85` | Revoke inherited public grants and re-grant only required table/column privileges |

The commit containing this report is a documentation-only child of `b61e8a07d59eea8dfb842c2d7ffb36243990ed85`.

## Implemented in this pass

### Mobile and portal UI

- Added shared navy/electric-blue/cyan design tokens, rounded surfaces, refreshed form/button styling, and a dark bottom-navigation shell.
- Added a five-destination mobile navigation: Home, Cases, GIS, Public works, Profile.
- Added dashboard shortcuts to notifications and India data coverage.
- Replaced the minimal profile with signed-in account identity, role/department, request/evidence/unread counts, requests, evidence, tracker, notifications, data coverage, password reset, help and sign-out links.
- Evidence listing is scoped to the authenticated uploader and opens the existing private-storage object with a short-lived signed URL.
- Added a public-notice entry on the sign-in page; reading published notices does not require sign-in.
- Retained the existing embedded, staff-gated case AI workflow; this pass did not create a second AI endpoint.

**Not complete:** this is a hybrid theme pass, not a full conversion of every screen to a dark-navy canvas. The four visual-reference screenshots were not available in the repository or accessible file context during this pass, so pixel-matched reproduction is not claimed. Role-selection, every staff page and the full command-centre layouts still need dedicated visual QA.

### GIS and underground-data boundary

- Switched the non-satellite MapLibre vector default to the OpenFreeMap dark style; existing satellite/hybrid and map interactions were retained where configured.
- Retained existing owner-department restrictions for exact underground utility geometry and existing generalized overview controls.
- No synthetic underground route or depth was added.
- No Google Street View-derived geometry was added.

**Not complete:** this pass did not import or validate nationwide Open Buildings, OpenStreetMap building, GHSL or OpenBuildingMap geometry, and did not add nationwide district/city/ward boundaries or a newly populated 3D national building layer. The dark vector style is a basemap change, not proof of nationwide asset coverage.

### Public excavation tracker

- Added public search across city, district, ward, area and notice code.
- Added work/no-dig notice cards, authority-reported dates/progress, responsible department and timeline view.
- Added authenticated obstruction submissions with reporter/private-reviewer access.
- Added additive database structures for notices, notice events and obstruction reports.
- No sample records were seeded. The tracker correctly remains empty until an authorised department publishes source-backed content.

**Not complete:** a full staff-facing notice authoring/moderation/assignment interface and source onboarding workflow still need implementation. There are no official notices loaded.

### Existing command-centre and AI capabilities

Existing request, department coordination, case messages, notifications, AI assessment and audit structures were retained. The existing AI workflow remains staff-gated in the case workspace and depends on its existing server-side configuration. This pass did not implement a new cross-ministry command-centre redesign, nor claim new clash/savings statistics.

## Live Supabase migration and privilege verification

Applied migrations:

- `add_public_excavation_tracker_and_obstruction_reports`
- `tune_public_tracker_select_policies_and_indexes`
- `revoke_default_public_tracker_grants`

Live schema inspection confirmed RLS enabled on all three new tables.

A direct privilege query returned:

| Check | Result |
|---|---:|
| Anonymous SELECT on published notices | allowed |
| Anonymous SELECT on public timeline events | allowed |
| Anonymous SELECT/INSERT/UPDATE on obstruction reports | denied |
| Authenticated SELECT/INSERT on own/reviewable obstruction reports | granted, subject to RLS |
| Authenticated DELETE on obstruction reports | denied |
| Authenticated UPDATE of reporter's submitted details | denied |
| Authenticated reviewer UPDATE of report status/assignment fields | granted, subject to RLS |

All tracker tables have RLS enabled. The reporter's details are not updateable through the authenticated table grant. No existing utility-geometry or evidence-storage policy was changed.

### Existing Supabase advisor findings

The project advisor still reports findings outside the new tracker tables, including a pre-existing security-definer view, authenticated-callable security-definer functions, RLS-enabled service-managed tables with no client policies, and leaked-password protection disabled. These need a separate, function-by-function security review. They were not changed during this pass. Health advisor returned no lints. New tracker foreign-key indexes were added; the advisor reports them unused while the tables are empty.

## Live data coverage snapshot

Counts read directly from the connected project on 9 November 2026:

| Data domain | Current records | Interpretation |
|---|---:|---|
| State/UT directory | 36 | State/UT master entries exist |
| Coverage metadata | 396 | Source/coverage metadata, not geometry |
| India administrative units | 0 | No district/sub-district/ULB/ward rows onboarded in this table |
| Groundwater state assessments | 36 | Existing assessment records |
| Groundwater district assessments | 225 | Existing district assessment records |
| Groundwater station observations | 1,641,126 | Source station observations; not the operational field-observation register |
| Operational groundwater observation register | 0 | No field observations in this register |
| Public building approval register records | 2,015 | Existing public-register extracts; not proof of nationwide verified building geometry |
| Building approval records | 2,015 | Existing records; geocoding/authority verification remains a separate quality gate |
| Utility layer catalogue | 125 | Catalogue entries only; not utility geometry |
| Restricted utility source records | 11 | Source metadata only |
| Registered underground assets | 0 | No owner-authorised utility geometry registered |
| Registered survey evidence | 0 | No registered survey evidence |
| Published public work notices | 0 | No official notices loaded |
| Public obstruction reports | 0 | No user reports submitted |

**Data interpretation:** the platform has nationwide administrative reference metadata and groundwater source observations, but does not currently have nationwide district/ward GIS units or verified underground network geometry. Empty registries must not be interpreted as “no utilities”. A published no-dig notice is not excavation clearance.

## CI and build results

### Browser portal

- Run: [42593522860](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42593522860)
- Source commit: `7c463725978eae276064738e392b27ee2c4722bc`
- Result: **success**
- Flutter dependency installation: passed
- Dart analysis: passed
- Browser build: passed
- Portal packaging and artifact upload: passed
- Artifact: `SAMANVAY-Browser-Portal` (14,665,907 bytes; SHA-256 `1923f700040d9c3b9a1d49ef1df46a23793380a8098ef7b586a4bc204038adf1`)

### Android release

- Latest source run: [42593523065](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42593523065)
- Source commit: `7c463725978eae276064738e392b27ee2c4722bc`
- Dependency installation: passed
- Dart analysis: passed
- Release APK build / package verification / signature and alignment checks: **in progress when reported**
- No artifact was available on that latest-source run at report time.

A previous Android run [42593116093](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/42593116093) on commit `c94c952d9e473e72a067a19ebd8c31672cc772ac` passed all workflow steps, including release APK build, package/signature/alignment verification, artifact upload and Alpha 0.3 prerelease publication. Its APK predates the later public sign-in shortcut and profile evidence viewer; it is not labelled as the latest-source APK.

## Remaining blockers

1. Import and validate LGD administrative units for districts, sub-districts, ULBs, wards and villages, with official source dates and code reconciliation.
2. Onboard independently licensed building sources (Open Buildings/OSM/GHSL/OpenBuildingMap as applicable), preserve source attribution and geometry/quality status, and complete national coverage QA.
3. Obtain owner-authorised utility geometry and survey evidence; verify provenance, coordinate reference system, department ownership and geometry through the existing independent review flow.
4. Load official groundwater and building data into operational, geospatially referenced records where authorised; separate source/reference observations from current field observations.
5. Build staff UI for notice creation, source validation, publication, timeline updates, complaint assignment and resolution.
6. Complete the screenshot-aligned visual redesign across login/role selection, dashboards, command centre, GIS panels, AI workspace and notifications; run device and browser responsive/accessibility QA.
7. Finish the latest-source Android release run and confirm APK artifact/signature/alignment checks.
8. Review pre-existing Supabase advisor findings separately; do not weaken utility/evidence restrictions to silence lints.

## Revised completion estimate

**Approximately 50% overall for the full national-platform scope.**

This is an implementation estimate against the user's seven requested sections, not a LOC or test-coverage metric. It reflects the mature existing backend and workflows plus this verified UI/tracker/security pass, while accounting for the still-empty underground registry, missing district/ward directory, incomplete national building GIS, absent official public notices and unfinished full UI redesign. It should not be represented as a production-ready nationwide deployment.
