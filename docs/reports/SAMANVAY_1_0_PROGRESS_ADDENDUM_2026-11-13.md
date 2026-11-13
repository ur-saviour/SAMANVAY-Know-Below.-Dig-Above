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

## 4. Profile editing database constraint — migration applied

A narrowly scoped migration, `20261113065528_profile_display_name_self_update`, was successfully applied to the live Supabase project and is committed in `supabase/migrations/20261113065528_profile_display_name_self_update.sql`.

The migration grants column-level UPDATE on `public.profiles.display_name` only and adds an UPDATE RLS policy requiring `id = auth.uid()` for both `USING` and `WITH CHECK`. A follow-up privilege query confirmed:
- authenticated can UPDATE `display_name`;
- authenticated cannot UPDATE `role`;
- authenticated cannot UPDATE `department_id`;
- authenticated has no unrestricted table-level UPDATE;
- the self-row UPDATE policy is installed.

The Profile page now includes an Edit name action with 2-character minimum, 80-character maximum, database persistence and refreshed profile data. The build and static checks verify this implementation; a live authenticated save attempt by a test user is still required before marking profile editing end-to-end accepted.

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

## 6. Decision

The latest source is improved and a new Alpha 0.3 APK is verified at the build/package level. The original integration branch remains untouched.

**Do not call this SAMANVAY 1.0 yet.** The current release still lacks physical-device acceptance, verified mobile OTP/recovery, safe profile editing, operational verified underground asset coverage, full authorization review, accessibility/performance evidence and production signing. Continue from this branch and close the acceptance gates in the baseline report before declaring 1.0.


## 7. GIS light-mode layer-sheet remediation

The GIS layer bottom sheet uses the theme's `panelNavy` surface, which is white in the legacy light palette. Its readiness headings, data integrity heading, switch titles and utility-screening text now use the active semantic foreground (`ink`) rather than fixed white. Deliberately dark map overlays retain white text. The first attempt introduced five invalid constant expressions; Android run #620 caught the issue during Dart analysis. Those five constant declarations were corrected in commit `5d45318`.

**Latest successful GIS-light-mode build:** [Android run #621](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43381818460), commit `5d453184a21fe68717044856b269d0ed4295fc19`. All configured build, analyzer, APK package, signature, alignment and artifact-publishing steps passed.

- Artifact ID: `14017640919`
- Artifact ZIP SHA-256: `3ad74e3a2433e75914bcd290841f3bccfa3cd412e1c87cd8cda88225bd1c9bb4`
- ARM64 APK SHA-256: `80912abd77db82f82a1882073423faf3627960dc48095e23d7f3e678dcb26cdb`
- Logo Git blob SHA within the built APK: `17c2db21509cfb59109cd413e8cb0f24d3f66524`, matching the original asset exactly.

This remains an Alpha 0.3 package and does not replace physical-device light/dark visual acceptance.
