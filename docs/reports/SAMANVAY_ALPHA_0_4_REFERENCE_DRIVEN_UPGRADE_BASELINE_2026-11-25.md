# SAMANVAY Alpha 0.4 — Reference-Driven Upgrade Baseline

**Audit date:** 25 November 2026  
**Baseline branch:** `feature/alpha-03-integrated-platform`  
**Baseline commit:** `caafecb34dd6bdf6752ff1603fcdfcbf6bbaa34f`  
**Upgrade branch:** `upgrade/alpha-04-reference-driven`

## Corrected source classification

The owner has clarified that the uploaded `SAMANVAY (2).apk` is the **reference application** for the upgrade. Earlier notes that classified it as the current app were incorrect and are superseded by this report. The APK was directly inspected from `/mnt/data/SAMANVAY (2).apk`.

The GitHub branch `feature/alpha-03-integrated-platform` is the source-code baseline to upgrade. The uploaded APK is the reference for the experience and specific implementation patterns, not the source branch to overwrite.

## Reference APK — verified findings

- APK size: approximately 87 MiB.
- Flutter Android application; contains native libraries for ARM64, ARMv7 and x86_64.
- Includes MapLibre native libraries.
- Bundles original SAMANVAY brand assets, including SVG/PNG/JPG logo variants and city/splash assets.
- Includes a self-contained Three.js underground visualisation:
  - `assets/cutaway/index.html`
  - `assets/cutaway/cutaway.js`
  - `assets/cutaway/three.min.js`
- The underground view uses a Three.js WebGL renderer, perspective camera, textured road/asphalt, concrete, gravel, soil/rock strata, utility meshes and on-screen labels.
- It supports 2D/3D mode buttons, pointer drag rotation, two-pointer pinch zoom, wheel zoom, raycast selection of utility objects, a selected-asset detail card and an “Open record” bridge callback.
- The visualisation receives data through `window.samanvayLoad(data)`; it also has a demo sample fallback.
- The source comments state that dimensions and depths are visually exaggerated to make the network readable on a phone. The demo site described in the source is Manaparai Bus Stand.
- The HTML explicitly labels the sample view “Sample records · not for excavation”.
- The cutaway is generated locally and does not load external model files. This is a presentation component, not evidence that all depicted utilities are verified or georeferenced.

### Reference experience design cues

- Light neutral background with earthy soil and rock materials.
- Textured asphalt road and opened ground cross-section.
- Distinct utility colours and floating labels.
- Compact white title card and 2D/3D segmented control at the top.
- Interactive asset-selection information card at the bottom.
- Direct touch affordances: drag, pinch, tap.
- Clear demo/not-for-excavation disclosure.

## Existing GitHub source baseline — verified comparison

- The source branch is `feature/alpha-03-integrated-platform`, commit `caafecb34dd6bdf6752ff1603fcdfcbf6bbaa34f`.
- The current `app/main.dart` branch uses `_AnimatedUndergroundCutaway` and `_DemoSubsurfacePainter`, a Flutter `CustomPainter` schematic. It is materially different from the reference APK's Three.js WebGL scene.
- The current source explicitly calls the painter synthetic and non-georeferenced and excludes it from GIS, excavation screening and clearance logic.
- This establishes a concrete upgrade gap: restore/integrate a Three.js-based interactive cutaway comparable to the reference, with data passed from Flutter and selected records bridged back to Flutter.
- The source repository contains the original SAMANVAY SVG logo at `app/assets/brand/samanvay_logo.svg`.
- The repository contains email/mobile OTP and password-recovery client-flow foundations. Provider delivery and real-device verification remain separate acceptance requirements.
- Role preview code uses local demo identities; it does not change authenticated permissions or grant protected staff access.

## GIS and data-governance constraints

- The source GIS uses MapLibre. The audit records MapLibre basemap and administrative-boundary foundations, plus guarded utility overview queries.
- The audit snapshot records zero rows in `gis.underground_assets`, zero rows in `gis.asset_survey_evidence`, and zero utility-geometry import runs.
- Groundwater observations in the bundled/reference data are not to be represented as live telemetry unless independently verified.
- National administrative and utility coverage catalogues are readiness/reference metadata, not nationwide verified underground coverage.
- An empty asset registry never means no underground utilities exist and never means excavation is safe.

## Alpha 0.4 upgrade priorities

1. **Reference parity specification:** use the inspected APK as the design/interaction target. Document screen hierarchy, navigation, brand treatment, motion, map controls and the Three.js cutaway interactions before broad UI changes.
2. **Underground 3D integration:** port or adapt the reference Three.js scene into the current Flutter GIS workflow. Retain WebGL performance safeguards, Android WebView compatibility checks, resize handling, reduced-motion consideration, touch gestures, raycast selection and Flutter-JavaScript bridge contracts.
3. **Data-driven rendering:** pass only authorised asset records into the scene. Preserve asset IDs, source, owner, material, size, installation metadata, depth, confidence/accuracy and verification status. Missing/unverified geometry must remain visibly unavailable or illustrative; never silently fill gaps with fabricated routes.
4. **GIS workspace:** improve map-first navigation, layer manager, search, legend, selected-feature details, date/status filters, source attribution, freshness and no-data states.
5. **Authentication and role experience:** simplify entry and verify email/mobile OTP, password recovery, Citizen registration and four role-gated workspaces. Demo switching remains visibly demo-only.
6. **Workflow completion:** validate citizen submissions, department assignment/review, coordinator joint-work proposals, administrator governance, evidence upload and audit history end to end.
7. **Release quality:** run static analysis, contract checks, widget/integration tests where feasible, Android build/signature checks and physical-device smoke tests.

## Non-negotiable preservation and safety rules

- Preserve the original SAMANVAY logo and brand identity.
- Use **Citizen** in visible UI; do not expose “Requester” as user-facing terminology.
- Preserve the existing Flutter/Supabase application and account data. No destructive schema or data changes without a reviewed migration and explicit approval.
- Demo/synthetic data must carry a visible demo/reference label and must not enter operational clearance logic.
- Never fabricate verified utility routes, depth, collisions, statutory clearance, official asset coverage or savings.
- Exact utility geometry remains restricted to authorised owner-side workflows.
- AI may support triage and explanation; it must not approve permits, make statutory determinations, certify utility locations or declare a site safe.

## Acceptance evidence required before Alpha 0.4 release

- [ ] Screen-by-screen reference parity specification completed.
- [ ] Original logo and approved brand assets unchanged.
- [ ] Three.js scene integrated with Flutter and tested on target Android devices.
- [ ] 2D/3D switching, rotation, pinch zoom, selection, detail card and record bridge tested.
- [ ] WebView/WebGL failure and low-memory fallback tested.
- [ ] Real-device email OTP and mobile OTP tests passed.
- [ ] Citizen, department officer, coordinator and administrator tests passed, including negative access tests.
- [ ] MapLibre vector/satellite basemaps, attribution, navigation, search, layer toggles and no-data states tested.
- [ ] Illustrative and operational geometry clearly separated.
- [ ] Evidence upload and workflow actions tested against Supabase.
- [ ] Empty/unverified registry state never implies clearance.
- [ ] Android APK installs, launches, survives navigation and passes physical-device smoke tests.
- [ ] Build artifact, commit SHA, test results and known limitations recorded.

## Current status

The reference APK has now been inspected at asset/source level. This commit records the corrected reference classification and the specific 3D implementation gap. It does not claim that application code has yet been changed, that the Three.js scene has been integrated into the current source, or that Alpha 0.4 has been built or device-tested.
