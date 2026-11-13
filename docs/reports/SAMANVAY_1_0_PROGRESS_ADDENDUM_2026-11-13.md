# SAMANVAY 1.0 — Professionalisation Progress Addendum

**Date:** 13 November 2026  
**Branch:** `feature/samanvay-1.0-professionalisation`  
**Verified source commit:** `0b1947d055e4893f9761bdc629218f5cd96bf299`  
**Build:** GitHub Actions run `43380232402` (#618), completed successfully.

This addendum records changes and validation completed after the baseline audit. It does not certify SAMANVAY 1.0 or claim physical-device acceptance.

## 1. Implemented changes

### Brand and opening lifecycle
- Restored the required tagline **Know Below. Dig Above.** in the app title, opening copy, GIS header and About copy.
- Retained the exact original `app/assets/brand/samanvay_logo.svg` asset; no artwork or logo path was substituted.
- Stopped the root ambient animation controller when the opening experience exits to the authenticated app.
- The original opening sequence was not comprehensively redesigned or device-timed in this increment.

### Theme contrast
- Replaced hard-coded white foreground text with the existing semantic theme foreground in the clearance workflow, live operations metrics, command-centre activity and public-works publishing/review panels.
- This is a targeted contrast correction, not a full screen-by-screen accessibility certification.

### Password recovery
- Added an AuthGate branch for `AuthChangeEvent.passwordRecovery` so a recovery-link session opens a dedicated password update screen rather than immediately opening the role dashboard.
- Added new-password and confirmation fields, minimum length validation, obscured input with a visibility control, loading/error handling and the Supabase `updateUser(UserAttributes(password: ...))` call.
- Unified the reset redirect to the existing `in.samanvay://login-callback/` app callback for the signed-out login reset and signed-in profile reset actions.
- Added source-contract regression checks for this recovery flow and the official tagline.

## 2. Android build and artifact verification

**Workflow:** [Build SAMANVAY Android APK — run 43380232402](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43380232402)

Every configured step completed successfully:
- contract validation;
- Android package generation and validation;
- Flutter dependency installation;
- Dart analysis;
- release APK compilation;
- package, signature and alignment verification;
- artifact upload and Alpha 0.3 publication.

**Artifact:** `SAMANVAY-Alpha-0.3-APK`  
**Artifact ID:** `14016602193`  
**Artifact ZIP size:** 44,577,550 bytes  
**Artifact ZIP SHA-256:** `1ac6f9c86fc6b630aac2e608c503eed5addef8ecce30eb59790052dfdc84aa9c`

The artifact contains three ABI APKs: ARM64, armeabi-v7a and x86_64.

### Independent archive inspection

All three APK files passed ZIP CRC verification. The ARM64 APK contains DEX classes, Flutter runtime libraries and the expected application asset layout.

- ARM64 APK size: 33,583,252 bytes
- ARM64 APK SHA-256: `328aaa67da002117f401e3dca5a59c6dacf65033808b60d60c5e214343628efb`
- Logo inside the built ARM64 APK has Git blob SHA: `17c2db21509cfb59109cd413e8cb0f24d3f66524`
- Original source logo Git blob SHA: `17c2db21509cfb59109cd413e8cb0f24d3f66524`

The logo bytes in the built APK therefore match the original source asset exactly.

**Limit:** The build system still names and publishes this package as **Alpha 0.3**. No production signing-key migration or 1.0 versioning has occurred. No physical Android installation, launch, live SMS, deep-link, or signed-in password-recovery journey was performed.

## 3. Latest Supabase advisor snapshot

Project: `zhtotivedvkmclerdnlf`. Advisor snapshot observed on 13 November 2026.

| Advisor | Current result |
|---|---:|
| Authenticated-executable SECURITY DEFINER functions | 18 warnings |
| Leaked-password protection | Disabled warning |
| Unindexed foreign keys | 5 findings |
| Unused indexes | 81 findings |
| Multiple permissive policies | 14 findings |
| Duplicate indexes | 1 finding |
| Health advisor lints | 0 |

SECURITY DEFINER is not automatically a vulnerability. A read-only review of representative administrative, department-assignment, workflow and GIS functions found an empty search path and explicit actor/role checks in the inspected definitions. This is not yet a complete review of all 18 functions, their EXECUTE grants, or negative caller test cases. Do not bulk-revoke these functions: that could break legitimate workflows or fail to close an authorization gap.

Leaked-password protection remains disabled. Its Auth provider setting has not been changed.

## 4. Profile editing database constraint

The live `public.profiles` table has columns `id`, `display_name`, `role`, `department_id` and `created_at`. The authenticated role currently has SELECT only; the only observed row policy is a self-row SELECT policy. There is no authenticated UPDATE grant or UPDATE RLS policy.

A client-side profile Save button would therefore be non-functional. Do not grant broad UPDATE rights on the profile row. A future, version-controlled migration may permit only `display_name` updates with a self-row `USING` and `WITH CHECK` policy, while leaving `role` and `department_id` non-updatable by normal clients. No live schema change was made in this increment.

## 5. Remaining release blockers

1. **Device acceptance:** install, first launch, upgrade, background/foreground, rotation/responsive layouts and restart on representative Android devices.
2. **Authentication E2E:** real provider SMS OTP for new and existing accounts; email recovery callback and actual password update; session expiry/logout; negative role/RLS tests for all four roles. Current account inventory previously recorded six users and no phone-confirmed accounts.
3. **Profile management:** introduce a safe, versioned display-name-only database migration and test it under authenticated RLS. Do not permit client-side role or department edits.
4. **GIS data:** the live operational underground asset and survey-evidence registries were empty in the latest recorded inventory. The public 250 m aggregate, owner-scoped verified geometry endpoint and synthetic cutaway must remain clearly distinguished. Obtain authorised surveyed assets before describing underground coverage as operational.
5. **Geographic reference data:** reconcile State/District/ULB/Ward records with authoritative data; retain explicit unmapped/unverified states.
6. **Security:** review all SECURITY DEFINER grants and caller checks; test denied calls; enable leaked-password protection after evaluating project plan and policy.
7. **Performance/accessibility:** measure real startup, frame pacing, memory, map/network loading and battery; test contrast, TalkBack, text scaling and touch targets.
8. **Build reproducibility:** commit a pinned Flutter dependency manifest and lockfile instead of resolving key packages at build time.
9. **Release signing:** replace the temporary debug signing certificate with a persistent owner-controlled release key stored in protected CI secrets and document backup/recovery.
10. **Operations:** exercise requests, assignment, reviews, permits, inspections, restoration, coordination, notifications and evidence integrity with controlled test accounts and records.



## 7. Additional Android correction and animation lifecycle — 13 November 2026

- The latest professionalisation-head build failed at Dart analysis after a light-mode GIS layer-sheet edit. The cause was five invalid constant-value usages where const widgets/styles referenced the runtime theme getter ink. The next review branch removes those const markers while retaining the dynamic theme-aware text.
- The branded opening keeps the official logo and flag sequence, but stages are reduced to 2.8 s (logo reveal), 1.4 s (flag transition) and 2.2 s (intro), with Get Started interactive at 82% of the final stage (~6.0 s total).
- The Citizen IndexedStack now wraps pages in TickerMode, enabling tickers only on the selected page. This preserves each page's state while preventing hidden pages' animation controllers—especially the GIS underground cutaway—from consuming frame work while the user is elsewhere.
- Source-contract checks cover the timing values, CTA threshold, animation stop and selected-page ticker gate.
- This is a source-level/performance implementation; frame pacing, CPU, battery and visual startup timing remain to be measured on a physical Android device.

## 6. Decision

The latest source is improved and a new Alpha 0.3 APK is verified at the build/package level. The original integration branch remains untouched.

**Do not call this SAMANVAY 1.0 yet.** The current release still lacks physical-device acceptance, verified mobile OTP/recovery, safe profile editing, operational verified underground asset coverage, full authorization review, accessibility/performance evidence and production signing. Continue from this branch and close the acceptance gates in the baseline report before declaring 1.0.
