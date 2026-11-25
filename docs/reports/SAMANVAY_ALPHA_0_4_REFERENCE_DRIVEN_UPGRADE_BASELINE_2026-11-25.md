# SAMANVAY Alpha 0.4 — Reference-Driven Upgrade Baseline

**Audit date:** 25 November 2026  
**Baseline branch:** `feature/alpha-03-integrated-platform`  
**Baseline commit:** `caafecb34dd6bdf6752ff1603fcdfcbf6bbaa34f`  
**Upgrade branch:** `upgrade/alpha-04-reference-driven`

## Scope and preservation rules

This is an upgrade of the existing SAMANVAY application, not a replacement project. Preserve the existing Flutter application, Supabase project and schema, original SAMANVAY brand assets, current account records, role model, and working workflows. Do not overwrite production data, expose secrets, or weaken role-based access controls to make a demo appear functional.

The reference application shared by the project owner through Google Drive has not yet been inspected in this execution. The supplied `SAMANVAY (2).apk` is the existing SAMANVAY build, not the reference target. Visual matching must not be guessed; the target APK or a screen recording is still required for faithful reconstruction.

## Baseline evidence

### Repository and builds

- Active baseline branch: `feature/alpha-03-integrated-platform`.
- Baseline commit: `caafecb34dd6bdf6752ff1603fcdfcbf6bbaa34f`.
- Android Actions run #637 completed successfully on the baseline commit.
- Browser Actions run #441 completed successfully on the baseline commit.
- These are CI build results, not physical-device acceptance results.

### Brand and authentication

- The repository contains the SAMANVAY SVG logo at `app/assets/brand/samanvay_logo.svg`.
- The Flutter entry point includes a branded opening experience.
- Email OTP and mobile OTP client flows are present, as is password-recovery code.
- The mobile dual-channel OTP documentation requires the Supabase Auth hook, provider secrets, approved sender/template configuration and a real-device test. Delivery must not be called verified until that test is completed.
- The source-level role mapping presents the internal `requester` role as **Citizen**.
- Citizen-to-staff profile switching opens local, read-only demo previews using `PUBLIC-*` identifiers. It does not change the authenticated account's role or grant access to protected production records.

### GIS and underground visualisation

- The map uses MapLibre with an OpenFreeMap vector style and an Esri World Imagery raster fallback; a MapTiler hybrid style is selected when a MapTiler key is configured.
- The map source includes India navigation, regional extents, reference boundary layers, groundwater observations and guarded utility-overview queries.
- The underground cutaway is implemented by `_AnimatedUndergroundCutaway` and `_DemoSubsurfacePainter` in `app/main.dart`.
- That cutaway is a fixed-coordinate Flutter `CustomPainter` illustration with animated particles. It is explicitly documented in source as synthetic and non-georeferenced. It is not a 3D GIS scene and must not be used for spatial screening or clearance.
- The GIS audit records zero rows in `gis.underground_assets`, zero rows in `gis.asset_survey_evidence`, and zero utility-geometry import runs at the audit snapshot.
- Groundwater observations are historical imported observations, not live telemetry. The audit records the newest source observation as 31 December 2025.
- National administrative and utility coverage catalogues are reference/readiness metadata, not nationwide verified underground coverage.

## Upgrade priorities

1. **Reference reconstruction:** inspect the actual reference APK/video and document its navigation, screen hierarchy, visual system, interaction patterns and motion before implementing visual changes.
2. **GIS workspace:** improve the map-first experience, responsive layer manager, search, legend, selected-feature details, date/status filters, source attribution, data freshness and no-data states.
3. **Underground digital-twin presentation:** replace the fixed cutaway with a navigable 3D presentation component, while keeping illustrative geometry clearly labelled and separate from operational GIS data. Only authorised, verified, georeferenced records may appear as operational utility geometry.
4. **Authentication and role experience:** simplify the entry flow and verify email/mobile OTP, password recovery, Citizen registration and the four role-gated workspaces. Demo switching must remain visibly demo-only.
5. **Workflow completion:** validate citizen submissions, department assignment/review, coordinator joint-work proposals, administrator governance, evidence upload and audit history end to end.
6. **Release quality:** run static analysis, contract checks, widget/integration tests where feasible, Android build/signature checks, and physical-device smoke tests. CI success alone is not release acceptance.

## Non-negotiable safety and data rules

- An empty asset registry never means that no underground utilities exist or that excavation is safe.
- Never fabricate verified utility routes, depth, collisions, statutory clearance, official asset coverage or savings.
- Demo/synthetic data must carry a visible demo/reference label and must not enter operational clearance logic.
- Exact utility geometry remains restricted to authorised owner-side workflows.
- AI may support triage and explanation; it must not approve permits, make statutory determinations, certify utility locations or declare a site safe.
- Preserve the original SAMANVAY logo and the Citizen terminology in all visible UI.

## Acceptance evidence required before Alpha 0.4 release

- [ ] Reference APK/video inspected and a screen-by-screen parity specification approved.
- [ ] Original logo and approved brand assets unchanged.
- [ ] Real-device email OTP and mobile OTP tests passed.
- [ ] Citizen, department officer, coordinator and administrator account tests passed, including negative access tests.
- [ ] MapLibre vector and satellite basemaps tested on-device; attribution visible.
- [ ] GIS navigation, search, layer toggles, map selection, GPS permission and no-data states tested.
- [ ] 3D presentation controls and layer visibility tested; illustrative and operational geometry clearly separated.
- [ ] Verified-asset empty state explicitly says unavailable/unverified and never implies clearance.
- [ ] Evidence upload and workflow actions tested against the connected Supabase project.
- [ ] Android APK installs, launches, survives navigation and passes smoke tests on a physical Android device.
- [ ] Build artifact, commit SHA, test results and known limitations recorded for the release.

## Current status

This commit records the baseline and acceptance gates only. It does not claim that the UI upgrade, 3D rewrite, backend deployment, device testing or Alpha 0.4 release has been completed.
