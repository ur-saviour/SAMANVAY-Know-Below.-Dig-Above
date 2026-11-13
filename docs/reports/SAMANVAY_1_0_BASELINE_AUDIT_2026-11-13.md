# SAMANVAY 1.0 — Baseline Engineering Audit

**Audit date:** 13 November 2026  
**Product baseline:** `feature/alpha-03-integrated-platform`  
**Baseline commit:** `154c2781e2c23fe835163c4312166f195c9d6694`  
**Working branch:** `feature/samanvay-1.0-experience-2026-11-13`  
**Rollback branch:** `backup/samanvay-alpha-03-before-1.0-2026-11-13`

## 1. Executive assessment

The full Alpha 0.3 application is the correct starting point for SAMANVAY 1.0. It is materially more complete than the separate Beta 0.2 recovery PR. The recovery PR is a reduced single-file build and a schematic GIS demonstration; it must not replace the integrated application baseline.

The full Alpha source contains the existing Flutter/Supabase application, original SAMANVAY brand assets, separate feature modules, MapLibre mapping, role-gated portals, and national/reference GIS work. Its Android release pipeline passed at the baseline commit and produced three ABI-specific APKs. This proves that the source passed that CI build and package checks; it does **not** prove installation, first launch, authentication delivery, or end-to-end workflows on a physical Android device.

**Release verdict: NOT SAMANVAY 1.0 yet.** The next gates are live authentication-provider verification, role/RLS acceptance, real device testing, live map/tile testing, GIS data readiness, accessibility, and measured performance.

## 2. Repository and build baseline

| Item | Evidence |
|---|---|
| Repository | `ur-saviour/SAMANVAY-Know-Below.-Dig-Above` |
| Main branch | `main` at `565c3a9196f17b5367ae7aae8011fc57a504dbdc` |
| Integrated application | `feature/alpha-03-integrated-platform` |
| Baseline commit | `154c2781e2c23fe835163c4312166f195c9d6694` |
| Android workflow | Run #573, ID `43319930779` |
| Android CI result | Success |
| Workflow artifact | `SAMANVAY-Alpha-0.3-APK`, artifact ID `13989519252` |
| Artifact digest | `sha256:38848b1ef6d51012ace4cbc13624a2a41f03b782b178f19705c6e2879f51675d` |
| APK variants | ARM64, ARMv7 and x86_64 |
| Package validation | `org.samanvay.samanvay`; ZIP integrity, package metadata, signature and alignment checks passed in CI |

The release workflow uses Java 21 and Flutter 3.38.0, runs source-contract validation and Dart analysis, builds split APKs, verifies package/signature/alignment, and uploads the result. The successful CI run is the last verified build baseline, not a device-tested production release.

### Separate Beta 0.2 recovery workflow

Run #610 (ID `43353944095`) on `beta-0.2/recovery` failed at `:url_launcher_android:lintVitalAnalyzeRelease`. Dart analysis and dependency installation had passed. The Gradle output reports an Android Lint internal failure with `NoSuchMethodError: JavaDocParser.parseDataItem`; APK preparation, signing inspection and upload were skipped. This failure belongs to the reduced recovery branch/toolchain path and is not evidence that the full Alpha baseline failed.

PR #12 explicitly describes its map as schematic and lists phone OTP, password recovery, role workspaces and device acceptance as outstanding. Keep that branch isolated; do not merge it over the integrated application.

## 3. Existing application architecture

- **Client:** Flutter/Dart Android application. The primary UI currently lives in `app/main.dart` (approximately 981 KB), with separate modules for evidence, public excavation tracking, transparency, coordination calendar, joint-work coordination and assistant experiences.
- **Backend:** Supabase Auth, Postgres/PostGIS-facing APIs/RPCs, Storage and Edge Functions.
- **Mapping:** MapLibre GL with OpenFreeMap/OpenStreetMap vector context, Esri World Imagery fallback and optional MapTiler hybrid style when the build key is supplied.
- **Brand resources:** `app/assets/brand/samanvay_logo.svg` and existing JPG/SVG/WebP companion assets. The Flutter UI references the original SVG logo. The Android build pipeline renders the same source logo into launcher-icon sizes; it does not need a redrawn logo.
- **Build structure:** the CI pipeline generates the Android scaffold and copies the repository's Flutter source/assets into the build workspace. Native runtime behavior still requires an Android install/launch test.

The monolithic primary Dart file is a maintainability concern. Refactor only incrementally, keeping feature contracts and test coverage intact; do not rewrite the product from scratch.

## 4. Feature inventory

Legend: **Source present** means the code/module is present. It is not a claim of completed end-to-end acceptance.

| Area | Audit classification | Evidence / limitation |
|---|---|---|
| Original SAMANVAY logo | Implemented in source | Existing SVG asset is referenced by the app and checked by CI. Preserve its bytes and geometry. |
| Opening experience | Implemented in source; device review pending | Animated splash/reveal, Indian-flag transition, introductory screen and Get Started path exist. The sequence includes a 7-second splash controller; timing and visual fidelity need a real-device review. |
| Approved tagline | Copy correction required | The current opening widget says “TOWARDS OUR DEVELOPMENT” and the MaterialApp title repeats that copy. The project identity brief specifies “Know Below. Dig Above.” This audit branch replaces only that copy; it does not modify the logo. |
| Citizen authentication | Partially verified | Email/password and phone/password sign-in code exists. Password reset is implemented. Actual account/session behavior needs device testing. |
| Email OTP | Configuration-dependent | OTP code and actionable handling exist; source documents a Supabase `otp_disabled` response for this project. Do not claim live email OTP until provider settings and a real delivery test pass. |
| Mobile registration and OTP | Configuration-dependent | Phone registration, signup OTP verification, resend cooldown and session checks exist. Live SMS delivery depends on Supabase Phone Auth, the Send SMS Hook, provider secrets, an approved sender/template and applicable India DLT configuration. No live-device delivery proof was available in this audit. |
| Officer/coordinator/admin access | Source present; authorization acceptance pending | RoleGate reads the Supabase profile and routes `department`, `coordinator` and `admin` roles to distinct portals. The backend remains the authority; official signup is an access request, not automatic privilege escalation. Test with real accounts and RLS. |
| Profile switching | Implemented as isolated demo | Profile switcher opens local read-only demo workspaces with `PUBLIC-*` identifiers. It does not impersonate an account, change a live role or grant production access. |
| Citizen dashboard and requests | Source present; E2E pending | Request listing and submission paths use Supabase tables. Create, status-change, attachment and notification behavior needs test-account verification. |
| Coordination and departmental workflows | Source present; E2E pending | Separate calendar/joint-work modules, role portals and corresponding database/Edge Function contracts exist. Exercise all transitions with authorised role sessions. |
| Road/excavation/restoration, drainage and building inspection | Source present; E2E pending | Operational boards and workflow code are present. No full regression/device pass was available in this audit. |
| Public works, groundwater and national coverage | Source present; data scope limited | Reference/telemetry and coverage experiences exist. A reference layer or authority directory is not proof that a complete national dataset has been imported. |
| GIS surface view | Source present; live rendering pending | MapLibre, vector/satellite style selection, regional navigation, place search, GPS, request markers and boundary/telemetry overlays are implemented. Network tile rendering and camera/gesture behavior must be checked on Android. |
| Underground view | Implemented as a controlled mix of reference/demo and protected data | Public users receive generalised coverage; exact verified utility geometry is restricted to authorised owner-department access. Illustrative cross-sections and synthetic layers must remain visibly labelled. |
| Verified underground inventory | Not available for operational claims | The latest documented GIS audit reported zero verified underground-asset rows and zero survey-evidence rows. Zero records means unknown/not supplied, never “no utility” or excavation clearance. |
| Light/dark theme | Source present; visual regression pending | ThemeMode is persisted using SharedPreferences; dark and light ThemeData definitions exist. Audit all components for hard-coded colors and contrast on device. |
| Security controls | Documented; independent acceptance pending | Security hardening notes document owner-scoped geometry access, restrictive RLS, metadata-only review queue and signed Edge Function checks. Retest current policies and RPCs with dedicated sessions. |
| Accessibility | Not verified | No TalkBack, large-font, contrast audit or touch-target test evidence was available. |
| Performance and battery | Not measured | No representative device profiler traces, startup timing, memory, frame timing, network or battery measurements were available. |
| Offline/poor network | Not verified | Retry/error UI exists in places; verify startup, GIS tiles, auth, uploads and request submission under network loss. |

## 5. Security and GIS trust boundaries

The project must preserve these non-negotiable boundaries:

1. Never infer authority from a client-side role selector. The signed-in Supabase profile, RLS and protected server functions determine access.
2. Demo profile switching is a local preview only. Keep it visibly marked and disconnected from privileged writes.
3. Public map views must not reveal exact underground utility routes, access points or depths. Use only the approved generalised coverage projection.
4. Exact utility geometry is accessible only through authorised owner-department flows. Do not weaken RLS or publish it in public map tiles.
5. Synthetic geometry must be labelled **DEMO DATA** and must never be stored or represented as a verified asset record.
6. Empty, stale, inaccessible or unverified data is **unknown**, not proof of absence and not excavation clearance.
7. Preserve dataset source, licence, retrieval date, CRS, accuracy, verification status and attribution. OpenStreetMap/Esri/MapTiler attribution must match the map style actually displayed.

## 6. Critical outstanding acceptance gates

- [ ] Fresh release build from the SAMANVAY 1.0 working branch.
- [ ] Install and launch on a physical Android device; record Android version, device class, app version and crash-free startup.
- [ ] Fresh Citizen registration, email/password login, phone signup, real OTP delivery, OTP verification, password reset, password update, logout and restart.
- [ ] Officer, Coordinator and Administrator account approval using dedicated real test accounts.
- [ ] Cross-role authorization tests: a role must not read/write another department's protected records.
- [ ] GIS vector and satellite tiles render on device with correct attribution; test India, North India, Tamil Nadu, district/city/ward paths.
- [ ] Public and owner-scoped underground layer responses match RLS expectations; no exact owner geometry reaches Citizens.
- [ ] Confirm all synthetic geometry is visibly labelled and no UI implies a real survey or safety clearance.
- [ ] Run request, evidence-upload, review, assignment, coordination, restoration and notification workflows end to end.
- [ ] Test light/dark theme on all major screens, small/large screens and large text settings.
- [ ] TalkBack/semantics, contrast, touch-target and reduced-motion review.
- [ ] Measure startup, scroll/map frame stability, memory, API latency and battery on a representative device.
- [ ] Reconcile repository migrations with the connected database before claiming a reproducible clean deployment.

## 7. Work performed in this professionalisation branch

- Created a rollback ref at `backup/samanvay-alpha-03-before-1.0-2026-11-13` pointing to the audited Alpha baseline commit.
- Created an isolated working ref at `feature/samanvay-1.0-experience-2026-11-13` from that same commit.
- Corrected the opening-screen tagline and app title to the approved wording without editing the logo asset.
- Added a source-contract assertion for the approved tagline so a later regression fails validation.
- Updated the Android CI workflow to run for this working branch and for its intended pull-request target.

## 8. Completion rule

SAMANVAY 1.0 is complete only when the critical acceptance gates above are tested and pass, a release APK is produced from the reviewed commit, APK package/signature/integrity are verified, and installation plus first launch are confirmed on Android. A successful Dart analysis or CI build alone is not a complete release.

---

**Evidence links**

- [Integrated branch](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/tree/feature/alpha-03-integrated-platform)
- [Successful Alpha 0.3 Android workflow run #573](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43319930779)
- [Failed Beta 0.2 recovery workflow run #610](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43353944095)
- [Beta 0.2 recovery PR #12 — not the product baseline](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/pull/12)
- [Authentication/OTP provider setup guide](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/blob/feature/alpha-03-integrated-platform/docs/AUTH_OTP_SETUP.md)
- [GIS source attribution and trust model](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/blob/feature/alpha-03-integrated-platform/docs/NATIONAL_GIS_SOURCE_ATTRIBUTION_AND_TRUST_MODEL.md)
- [Security hardening record](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/blob/feature/alpha-03-integrated-platform/docs/SECURITY_HARDENING_2026-11-12.md)
